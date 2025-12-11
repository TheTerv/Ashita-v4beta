--[[
    Windower 'texts' library compatibility shim for Ashita v4

    Maps Windower's texts API to Ashita's fonts library.
    This allows XivParty's uiText.lua to work with minimal changes.
]]--

local fonts = require('fonts');

local texts = {};

-- Store references to wrapped text objects
local textCache = {};

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
-- Text wrapper object
-- Provides Windower-compatible methods on top of Ashita fonts
----------------------------------------------------------------------------------------------------
local TextWrapper = {};
TextWrapper.__index = TextWrapper;

function TextWrapper:new(prim, settings)
    local obj = setmetatable({}, TextWrapper);
    obj.prim = prim;
    obj.colorR = 255;
    obj.colorG = 255;
    obj.colorB = 255;
    obj.colorA = 255;
    obj.strokeR = 0;
    obj.strokeG = 0;
    obj.strokeB = 0;
    obj.strokeA = 255;
    obj.fontSize = 10;
    obj.strokeWidth = 1;
    obj.alignRight = settings and settings.flags and settings.flags.right or false;
    return obj;
end

-- Set the text content
function TextWrapper:text(content)
    self.prim.text = content or '';
end

-- Set position
function TextWrapper:pos(x, y)
    self.prim.position_x = x or 0;
    self.prim.position_y = y or 0;
end

-- Set font size
function TextWrapper:size(fontSize)
    self.fontSize = fontSize or 10;
    self.prim.font_height = self.fontSize;
end

-- Set visibility
function TextWrapper:visible(isVisible)
    self.prim.visible = isVisible or false;
end

-- Set text color (RGB only, alpha separate)
function TextWrapper:color(r, g, b)
    self.colorR = r or 255;
    self.colorG = g or 255;
    self.colorB = b or 255;
    self.prim.color = colorToHex(self.colorA, self.colorR, self.colorG, self.colorB);
end

-- Set text alpha
function TextWrapper:alpha(a)
    self.colorA = a or 255;
    self.prim.color = colorToHex(self.colorA, self.colorR, self.colorG, self.colorB);
end

-- Set font family
function TextWrapper:font(fontFamily, fallback)
    self.prim.font_family = fontFamily or fallback or 'Arial';
end

-- Set stroke/outline color
function TextWrapper:stroke_color(r, g, b)
    self.strokeR = r or 0;
    self.strokeG = g or 0;
    self.strokeB = b or 0;
    self.prim.color_outline = colorToHex(self.strokeA, self.strokeR, self.strokeG, self.strokeB);
end

-- Set stroke/outline alpha
function TextWrapper:stroke_alpha(a)
    self.strokeA = a or 255;
    self.prim.color_outline = colorToHex(self.strokeA, self.strokeR, self.strokeG, self.strokeB);
end

-- Set stroke width (Ashita uses padding for outline effect)
function TextWrapper:stroke_width(width)
    self.strokeWidth = width or 1;
    -- Ashita's font outline is controlled via color_outline
    -- The actual outline thickness isn't directly configurable like Windower
    -- We approximate by ensuring outline color is set
    if width > 0 then
        self.prim.color_outline = colorToHex(self.strokeA, self.strokeR, self.strokeG, self.strokeB);
    else
        self.prim.color_outline = 0x00000000; -- Transparent = no outline
    end
end

-- Set background visibility
function TextWrapper:bg_visible(isVisible)
    local bg = self.prim.background;
    if bg then
        bg.visible = isVisible or false;
    end
end

-- Set draggable (Ashita uses 'locked' - inverted logic)
function TextWrapper:draggable(isDraggable)
    self.prim.locked = not isDraggable;
end

----------------------------------------------------------------------------------------------------
-- Public API (matches Windower's texts library)
----------------------------------------------------------------------------------------------------

-- Create a new text object
function texts.new(settings)
    settings = settings or {};

    local fontSettings = {
        visible = false,
        locked = true,
        can_focus = false,
        font_family = 'Arial',
        font_height = 10,
        color = 0xFFFFFFFF,
        color_outline = 0xFF000000,
        right_justified = settings.flags and settings.flags.right or false,
        background = {
            visible = false,
        },
    };

    local prim = fonts.new(fontSettings);
    local wrapper = TextWrapper:new(prim, settings);

    -- Store in cache for cleanup
    table.insert(textCache, wrapper);

    return wrapper;
end

-- Destroy a text object
function texts.destroy(textWrapper)
    if textWrapper and textWrapper.prim then
        -- Remove from cache
        for i, v in ipairs(textCache) do
            if v == textWrapper then
                table.remove(textCache, i);
                break;
            end
        end

        -- Destroy the font object
        textWrapper.prim:destroy();
        textWrapper.prim = nil;
    end
end

return texts;
