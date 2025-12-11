--[[
    Windower 'images' library compatibility shim for Ashita v4

    Maps Windower's images API to Ashita's primitives library.
    This allows XivParty's uiImage.lua to work with minimal changes.
]]--

local primitives = require('primitives');

local images = {};

-- Store references to wrapped image objects
local imageCache = {};

----------------------------------------------------------------------------------------------------
-- Helper: Convert ARGB color components to Ashita's 0xAARRGGBB format
----------------------------------------------------------------------------------------------------
local function colorToHex(a, r, g, b)
    a = a or 255;
    r = r or 255;
    g = g or 255;
    b = b or 255;
    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(r, 16),
        bit.lshift(g, 8),
        b
    );
end

----------------------------------------------------------------------------------------------------
-- Image wrapper object
-- Provides Windower-compatible methods on top of Ashita primitives
----------------------------------------------------------------------------------------------------
local ImageWrapper = {};
ImageWrapper.__index = ImageWrapper;

function ImageWrapper:new(primObj)
    local obj = setmetatable({}, ImageWrapper);
    obj.prim = primObj;
    obj.colorR = 255;
    obj.colorG = 255;
    obj.colorB = 255;
    obj.colorA = 255;
    obj.imgPath = nil;
    obj.imgWidth = 0;
    obj.imgHeight = 0;
    return obj;
end

-- Set the image file path
function ImageWrapper:path(filePath)
    if not filePath or filePath == '' then return end

    -- Normalize slashes to backslashes for Windows
    local normalizedPath = filePath:gsub('/', '\\');
    local fullPath = normalizedPath;

    -- Check if path is already absolute (drive letter like C:\)
    local isAbsolute = normalizedPath:match('^%a:\\');

    if not isAbsolute then
        -- Prepend addon path for relative paths
        local addonPath = windower.addon_path or '';
        fullPath = addonPath .. normalizedPath;
    end

    self.prim.texture = fullPath;
    self.imgPath = filePath;
end

-- Set position
function ImageWrapper:pos(x, y)
    self.prim.position_x = x or 0;
    self.prim.position_y = y or 0;
end

-- Set size
function ImageWrapper:size(w, h)
    self.imgWidth = w or 0;
    self.imgHeight = h or 0;
    self.prim.width = self.imgWidth;
    self.prim.height = self.imgHeight;
end

-- Set visibility
function ImageWrapper:visible(isVisible)
    self.prim.visible = isVisible or false;
end

-- Set color (RGB only, alpha separate)
function ImageWrapper:color(r, g, b)
    self.colorR = r or 255;
    self.colorG = g or 255;
    self.colorB = b or 255;
    self.prim.color = colorToHex(self.colorA, self.colorR, self.colorG, self.colorB);
end

-- Set alpha
function ImageWrapper:alpha(a)
    self.colorA = a or 255;
    self.prim.color = colorToHex(self.colorA, self.colorR, self.colorG, self.colorB);
end

-- Set draggable (Ashita uses 'locked' - inverted logic)
function ImageWrapper:draggable(isDraggable)
    self.prim.locked = not isDraggable;
end

-- Set fit mode (Ashita primitives always stretch to size)
function ImageWrapper:fit(doFit)
    -- Ashita primitives don't have a direct 'fit' equivalent
    -- When fit is false in Windower, scaling is applied
    -- We'll handle this via size calculations
end

-- Set repeat/tile
function ImageWrapper:repeat_xy(x, y)
    -- Ashita primitives use texture_offset for tiling effects
    -- For now, this is a no-op as XivParty doesn't heavily rely on tiling
end

-- Hit test for mouse hover
function ImageWrapper:hover(mouseX, mouseY)
    local x = self.prim.position_x;
    local y = self.prim.position_y;
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
    local primSettings = {
        visible = false,
        locked = true,
        can_focus = false,
    };

    local prim = primitives.new(primSettings);
    local wrapper = ImageWrapper:new(prim);

    -- Store in cache for cleanup
    table.insert(imageCache, wrapper);

    return wrapper;
end

-- Destroy an image
function images.destroy(imageWrapper)
    if imageWrapper and imageWrapper.prim then
        -- Remove from cache
        for i, v in ipairs(imageCache) do
            if v == imageWrapper then
                table.remove(imageCache, i);
                break;
            end
        end

        -- Destroy the primitive
        imageWrapper.prim:destroy();
        imageWrapper.prim = nil;
    end
end

return images;
