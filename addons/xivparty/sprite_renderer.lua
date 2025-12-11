--[[
    XivParty - D3D8 Sprite Renderer

    Handles texture loading and sprite rendering using D3D8 directly.
    This bypasses Ashita's primitives library to support Non-Power-Of-Two (NPOT) textures.

    Based on patterns from equipmon and tCrossBar addons.
]]--

local d3d8 = require('d3d8');
local ffi = require('ffi');
local C = ffi.C;

-- Load D3D8 type definitions (D3DFMT, D3DPOOL, etc.)
require('d3d8.d3d8types');

-- Load D3DX8 definitions (D3DXCreateSprite, D3DXCreateTextureFromFileExA, etc.)
require('d3d8.d3dx8');

local sprite_renderer = {};

-- D3D8 device reference
local d3d8_device = nil;

-- Sprite object for rendering
local sprite = nil;

-- Texture cache: path -> {texture, width, height}
local textureCache = {};

-- Draw queue: list of items to draw each frame
local drawQueue = {};

-- Module state
local isInitialized = false;

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function sprite_renderer.init()
    if isInitialized then return true end

    print('[XivParty/sprite_renderer] Initializing...');

    -- Get D3D8 device
    local ok, err = pcall(function()
        d3d8_device = d3d8.get_device();
    end);
    if not ok then
        print('[XivParty/sprite_renderer] Error: Exception getting D3D8 device: ' .. tostring(err));
        return false;
    end
    if d3d8_device == nil then
        print('[XivParty/sprite_renderer] Error: Failed to get D3D8 device (nil)');
        return false;
    end
    print('[XivParty/sprite_renderer] Got D3D8 device: ' .. tostring(d3d8_device));

    -- Create sprite object
    local sprite_ptr = ffi.new('ID3DXSprite*[1]');
    local createResult;
    ok, err = pcall(function()
        createResult = C.D3DXCreateSprite(d3d8_device, sprite_ptr);
    end);
    if not ok then
        print('[XivParty/sprite_renderer] Error: Exception creating sprite: ' .. tostring(err));
        return false;
    end
    if createResult ~= C.S_OK then
        print('[XivParty/sprite_renderer] Error: Failed to create sprite object (HRESULT: ' .. tostring(createResult) .. ')');
        return false;
    end
    sprite = d3d8.gc_safe_release(ffi.cast('ID3DXSprite*', sprite_ptr[0]));
    print('[XivParty/sprite_renderer] Created sprite object: ' .. tostring(sprite));

    isInitialized = true;
    print('[XivParty/sprite_renderer] Initialized successfully');
    return true;
end

function sprite_renderer.shutdown()
    -- Clear texture cache (textures will be released by gc_safe_release)
    textureCache = {};
    drawQueue = {};
    sprite = nil;
    d3d8_device = nil;
    isInitialized = false;
end

----------------------------------------------------------------------------------------------------
-- Texture Loading
----------------------------------------------------------------------------------------------------

function sprite_renderer.loadTexture(path)
    if not isInitialized then
        print('[XivParty/sprite_renderer] loadTexture: not initialized, calling init...');
        sprite_renderer.init();
    end

    -- Check cache first
    if textureCache[path] then
        print('[XivParty/sprite_renderer] loadTexture: returning cached texture for ' .. path);
        return textureCache[path];
    end

    print('[XivParty/sprite_renderer] loadTexture: loading ' .. path);

    -- Verify file exists
    local f = io.open(path, 'rb');
    if not f then
        print('[XivParty/sprite_renderer] Warning: Texture not found: ' .. path);
        return nil;
    end
    f:close();
    print('[XivParty/sprite_renderer] loadTexture: file exists');

    -- Helper: get next power of 2
    local function nextPow2(n)
        local p = 1;
        while p < n do p = p * 2 end
        return p;
    end

    -- First, get the image info to know original dimensions
    local imgInfo = ffi.new('D3DXIMAGE_INFO');
    local infoResult;
    local ok, err = pcall(function()
        infoResult = C.D3DXGetImageInfoFromFileA(path, imgInfo);
    end);

    if not ok or infoResult ~= C.S_OK then
        print('[XivParty/sprite_renderer] Warning: Could not get image info, using defaults');
        imgInfo.Width = 256;
        imgInfo.Height = 256;
    end

    local origWidth = imgInfo.Width;
    local origHeight = imgInfo.Height;
    local pow2Width = nextPow2(origWidth);
    local pow2Height = nextPow2(origHeight);

    print(string.format('[XivParty/sprite_renderer] loadTexture: orig=%dx%d pow2=%dx%d',
        origWidth, origHeight, pow2Width, pow2Height));

    -- Load texture with explicit POW2 dimensions (D3D8 requires POW2)
    local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
    local result;
    ok, err = pcall(function()
        result = C.D3DXCreateTextureFromFileExA(
            d3d8_device,
            path,
            pow2Width,          -- Width (forced to POW2)
            pow2Height,         -- Height (forced to POW2)
            1,                  -- MipLevels
            0,                  -- Usage
            C.D3DFMT_A8R8G8B8,  -- Format
            C.D3DPOOL_MANAGED,  -- Pool
            C.D3DX_DEFAULT,     -- Filter (will scale/stretch to POW2)
            C.D3DX_DEFAULT,     -- MipFilter
            0x00000000,         -- ColorKey (0 = no color key)
            nil,                -- pSrcInfo
            nil,                -- pPalette
            texture_ptr
        );
    end);

    if not ok then
        print('[XivParty/sprite_renderer] Error: Exception loading texture: ' .. tostring(err));
        return nil;
    end

    if result ~= C.S_OK then
        print('[XivParty/sprite_renderer] Error: Failed to load texture: ' .. path .. ' (HRESULT: ' .. tostring(result) .. ')');
        return nil;
    end

    print('[XivParty/sprite_renderer] loadTexture: D3DXCreateTextureFromFileExA succeeded');

    local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));

    -- Get texture dimensions
    local hr, desc = texture:GetLevelDesc(0);
    if hr ~= 0 then
        print('[XivParty/sprite_renderer] Error: Failed to get texture desc: ' .. path);
        return nil;
    end

    print('[XivParty/sprite_renderer] loadTexture: texture dimensions ' .. desc.Width .. 'x' .. desc.Height);

    -- Cache the texture
    local texInfo = {
        texture = texture,
        width = desc.Width,
        height = desc.Height,
    };
    textureCache[path] = texInfo;

    return texInfo;
end

function sprite_renderer.unloadTexture(path)
    textureCache[path] = nil;
end

function sprite_renderer.clearTextureCache()
    textureCache = {};
end

----------------------------------------------------------------------------------------------------
-- Draw Queue Management
----------------------------------------------------------------------------------------------------

-- Register an image for drawing
-- Returns an ID that can be used to update/remove the image
local nextImageId = 1;

function sprite_renderer.createImage()
    local id = nextImageId;
    nextImageId = nextImageId + 1;

    drawQueue[id] = {
        id = id,
        texture = nil,
        texInfo = nil,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        srcX = 0,
        srcY = 0,
        srcWidth = 0,
        srcHeight = 0,
        color = 0xFFFFFFFF,
        visible = false,
        scaleX = 1.0,
        scaleY = 1.0,
    };

    return id;
end

function sprite_renderer.destroyImage(id)
    drawQueue[id] = nil;
end

function sprite_renderer.setImageTexture(id, path)
    local img = drawQueue[id];
    if not img then return end

    local texInfo = sprite_renderer.loadTexture(path);
    if texInfo then
        img.texInfo = texInfo;
        -- Default source rect to full texture
        img.srcWidth = texInfo.width;
        img.srcHeight = texInfo.height;
    else
        img.texInfo = nil;
    end
end

function sprite_renderer.setImagePosition(id, x, y)
    local img = drawQueue[id];
    if not img then return end
    img.x = math.floor(x or 0);
    img.y = math.floor(y or 0);
end

function sprite_renderer.setImageSize(id, width, height)
    local img = drawQueue[id];
    if not img then return end
    img.width = math.floor(width or 0);
    img.height = math.floor(height or 0);

    -- Calculate scale based on desired size vs texture size
    if img.texInfo then
        img.scaleX = img.width / img.texInfo.width;
        img.scaleY = img.height / img.texInfo.height;
    end
end

function sprite_renderer.setImageSourceRect(id, x, y, width, height)
    local img = drawQueue[id];
    if not img then return end
    img.srcX = x or 0;
    img.srcY = y or 0;
    img.srcWidth = width or (img.texInfo and img.texInfo.width or 0);
    img.srcHeight = height or (img.texInfo and img.texInfo.height or 0);
end

function sprite_renderer.setImageColor(id, color)
    local img = drawQueue[id];
    if not img then return end
    img.color = color or 0xFFFFFFFF;
end

function sprite_renderer.setImageColorRGBA(id, r, g, b, a)
    local img = drawQueue[id];
    if not img then return end
    a = a or 255;
    r = r or 255;
    g = g or 255;
    b = b or 255;
    img.color = bit.bor(
        bit.lshift(a, 24),
        bit.lshift(r, 16),
        bit.lshift(g, 8),
        b
    );
end

function sprite_renderer.setImageVisible(id, visible)
    local img = drawQueue[id];
    if not img then return end
    img.visible = visible;
end

function sprite_renderer.setImageAlpha(id, alpha)
    local img = drawQueue[id];
    if not img then return end
    -- Preserve RGB, update alpha
    local rgb = bit.band(img.color, 0x00FFFFFF);
    img.color = bit.bor(bit.lshift(alpha, 24), rgb);
end

function sprite_renderer.getImageInfo(id)
    return drawQueue[id];
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

-- Pre-allocated FFI objects for rendering (avoid allocation in render loop)
local vec_position = ffi.new('D3DXVECTOR2', { 0, 0 });
local vec_scale = ffi.new('D3DXVECTOR2', { 1.0, 1.0 });
local rect = ffi.new('RECT', { 0, 0, 0, 0 });

-- Debug: track render calls
local renderCallCount = 0;
local lastRenderDebugTime = 0;

function sprite_renderer.render()
    if not isInitialized or sprite == nil then return end

    renderCallCount = renderCallCount + 1;

    -- Begin sprite rendering
    local beginOk, beginErr = pcall(function()
        sprite:Begin();
    end);
    if not beginOk then
        if renderCallCount <= 5 then
            print('[XivParty/sprite_renderer] Error in sprite:Begin(): ' .. tostring(beginErr));
        end
        return;
    end

    -- Draw all visible images
    local drawnCount = 0;
    for id, img in pairs(drawQueue) do
        if img.visible and img.texInfo then
            -- Set up source rectangle
            rect.left = img.srcX;
            rect.top = img.srcY;
            rect.right = img.srcX + img.srcWidth;
            rect.bottom = img.srcY + img.srcHeight;

            -- Set up scale
            vec_scale.x = img.scaleX;
            vec_scale.y = img.scaleY;

            -- Set up position
            vec_position.x = img.x;
            vec_position.y = img.y;

            -- Debug: log first few images' details
            if renderCallCount <= 2 and drawnCount < 3 then
                print(string.format('[sprite_renderer] Drawing id=%d pos=(%d,%d) scale=(%.2f,%.2f) rect=(%d,%d,%d,%d) color=0x%08X',
                    id, img.x, img.y, img.scaleX, img.scaleY,
                    rect.left, rect.top, rect.right, rect.bottom, img.color));
            end

            -- Draw the sprite
            local drawOk, drawErr = pcall(function()
                sprite:Draw(img.texInfo.texture, rect, vec_scale, nil, 0.0, vec_position, img.color);
            end);
            if not drawOk then
                if renderCallCount <= 5 then
                    print('[XivParty/sprite_renderer] Error in sprite:Draw(): ' .. tostring(drawErr));
                end
            else
                drawnCount = drawnCount + 1;
            end
        end
    end

    -- End sprite rendering
    local endOk, endErr = pcall(function()
        sprite:End();
    end);
    if not endOk then
        if renderCallCount <= 5 then
            print('[XivParty/sprite_renderer] Error in sprite:End(): ' .. tostring(endErr));
        end
    end

    -- Debug output (only first few calls)
    if renderCallCount <= 3 then
        print('[XivParty/sprite_renderer] render() call #' .. renderCallCount .. ', drew ' .. drawnCount .. ' images');
    end
end

----------------------------------------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------------------------------------

function sprite_renderer.isInitialized()
    return isInitialized;
end

function sprite_renderer.getTextureInfo(path)
    return textureCache[path];
end

function sprite_renderer.getDrawQueueCount()
    local count = 0;
    for _ in pairs(drawQueue) do
        count = count + 1;
    end
    return count;
end

return sprite_renderer;
