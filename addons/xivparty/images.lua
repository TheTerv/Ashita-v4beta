--[[
    Windower 'images' library compatibility shim for Ashita v4

    Uses Ashita's primitives library for rendering.
    NOTE: Requires POW2 textures - NPOT textures will render as black.
]]--

local primitives = require('primitives');

local images = {};

-- Store references to wrapped image objects
local imageCache = {};

----------------------------------------------------------------------------------------------------
-- Image wrapper object
-- Provides Windower-compatible methods on top of Ashita primitives
----------------------------------------------------------------------------------------------------
local ImageWrapper = {};
ImageWrapper.__index = ImageWrapper;

function ImageWrapper:new()
    local obj = setmetatable({}, ImageWrapper);

    -- Create a primitive
    obj.prim = primitives.new({
        visible = false,
        locked = true,
        can_focus = false,
        color = 0xFFFFFFFF,
    });

    obj.imgPath = nil;
    obj.imgWidth = 0;
    obj.imgHeight = 0;
    obj.posX = 0;
    obj.posY = 0;
    obj.isVisible = false;
    obj.colorR = 255;
    obj.colorG = 255;
    obj.colorB = 255;
    obj.colorA = 255;

    return obj;
end

-- Set the image file path
function ImageWrapper:path(filePath)
    if not filePath or filePath == '' then return end

    -- Normalize slashes to forward slashes for Ashita
    local normalizedPath = filePath:gsub('\\', '/');
    local fullPath = normalizedPath;

    -- Check if path is already absolute (drive letter like C:/)
    local isAbsolute = normalizedPath:match('^%a:/');

    if not isAbsolute then
        -- Prepend addon path for relative paths
        local addonPath = addon.path or '';
        fullPath = addonPath .. '/' .. normalizedPath;
    end

    self.imgPath = fullPath;
    self.prim:SetTextureFromFile(fullPath);
end

-- Set position (forced to integers to prevent sub-pixel rendering artifacts)
function ImageWrapper:pos(x, y)
    self.posX = math.floor(x or 0);
    self.posY = math.floor(y or 0);
    self.prim.position_x = self.posX;
    self.prim.position_y = self.posY;
end

-- Set size (forced to integers to prevent sub-pixel rendering artifacts)
function ImageWrapper:size(w, h)
    self.imgWidth = math.floor(w or 0);
    self.imgHeight = math.floor(h or 0);
    self.prim.width = self.imgWidth;
    self.prim.height = self.imgHeight;
end

-- Set visibility
function ImageWrapper:visible(isVisible)
    self.isVisible = isVisible or false;
    self.prim.visible = self.isVisible;
end

-- Set color (RGB only, alpha separate)
function ImageWrapper:color(r, g, b)
    self.colorR = r or 255;
    self.colorG = g or 255;
    self.colorB = b or 255;
    self:updateColor();
end

-- Set alpha
function ImageWrapper:alpha(a)
    self.colorA = a or 255;
    self:updateColor();
end

-- Update the primitive's color from RGBA components
function ImageWrapper:updateColor()
    self.prim.color = bit.bor(
        bit.lshift(self.colorA, 24),
        bit.lshift(self.colorR, 16),
        bit.lshift(self.colorG, 8),
        self.colorB
    );
end

-- Set draggable (Ashita uses 'locked' - inverted logic)
function ImageWrapper:draggable(isDraggable)
    self.prim.locked = not isDraggable;
end

-- Set fit mode (no-op for primitives)
function ImageWrapper:fit(doFit)
    -- Primitives handle scaling via width/height
end

-- Set repeat/tile (no-op)
function ImageWrapper:repeat_xy(x, y)
    -- Not supported by primitives
end

-- Hit test for mouse hover
function ImageWrapper:hover(mouseX, mouseY)
    local x = self.posX;
    local y = self.posY;
    local w = self.imgWidth;
    local h = self.imgHeight;

    return mouseX >= x and mouseX <= (x + w) and
           mouseY >= y and mouseY <= (y + h);
end

----------------------------------------------------------------------------------------------------
-- Public API (matches Windower's images library)
----------------------------------------------------------------------------------------------------

-- Create a new image
function images.new(settings)
    local wrapper = ImageWrapper:new();

    -- Store in cache for cleanup
    table.insert(imageCache, wrapper);

    return wrapper;
end

-- Destroy an image
function images.destroy(imageWrapper)
    if imageWrapper then
        -- Remove from cache
        for i, v in ipairs(imageCache) do
            if v == imageWrapper then
                table.remove(imageCache, i);
                break;
            end
        end

        -- Destroy the primitive
        if imageWrapper.prim then
            imageWrapper.prim:destroy();
            imageWrapper.prim = nil;
        end
    end
end

-- Render (no-op for primitives - they render automatically)
function images.render()
    -- Primitives are rendered by Ashita automatically
end

-- Initialize (no-op for primitives)
function images.init()
    return true;
end

-- Shutdown
function images.shutdown()
    -- Destroy all cached images
    for _, wrapper in ipairs(imageCache) do
        if wrapper.prim then
            wrapper.prim:destroy();
        end
    end
    imageCache = {};
end

return images;
