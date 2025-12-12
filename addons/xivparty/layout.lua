--[[
	Copyright © 2023, Tylas
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

		* Redistributions of source code must retain the above copyright
		  notice, this list of conditions and the following disclaimer.
		* Redistributions in binary form must reproduce the above copyright
		  notice, this list of conditions and the following disclaimer in the
		  documentation and/or other materials provided with the distribution.
		* Neither the name of XivParty nor the
		  names of its contributors may be used to endorse or promote products
		  derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

-- DO NOT EDIT VALUES IN THIS FILE if you want to customize a layout, edit the XML files in the layouts directory instead.
-- This file only contains default values and changes wont have any effect!

-- All positions, scales and z-orders are relative to an element's parent.
-- Scale affects all positions and sizes, snapToRaster only affects positions.
-- Due to a windower limitation, z-orders only work between the same type of element (image, text). Texts will always be placed above images!

-- helper functions
local function element(values)
	local ret = {
		enabled = false,
		pos = T{ 0, 0 },
		scale = T{ 1, 1 },
		zOrder = 0,
		snapToRaster = false
	}

	if values ~= nil then
		table.merge(ret, values, true)
	end

	return ret
end

local function image(values)
	local ret = table.merge(element(), {
		path = '',
		size = T{ 0, 0 },
		color = '#FFFFFFFF'
	}, true)

	if values ~= nil then
		table.merge(ret, values, true)
	end

	return ret
end

local function text(values)
	local ret = table.merge(element(), {
		font = 'Arial',
		size = 12,
		color = '#FFFFFFFF',
		stroke = '#000000FF',
		strokeWidth = 1,
		alignRight = false,
		maxChars = 0
	}, true)

	if values ~= nil then
		table.merge(ret, values, true)
	end

	return ret
end

local layout = {
	partyList = {
		rows = 6,
		columns = 1,
		rowHeight = 46,
		columnWidth = 410,

		-- Background
		background = element({
			pos = T{ 0, -21 },
			imgTop = image({
				pos = T{ 0, 0 },
				path = 'assets/xiv/BgTop.png',
				size = T{ 377, 21 },
				color = '#FFFFFFDD'
			}),
			imgMid = image({
				pos = T{ 0, 21 },
				path = 'assets/xiv/BgMid.png', -- this texture is repeated vertically when the list resizes
				size = T{ 377, 12 }, -- Y size will be overwritten in code, value here still required as a base
				color = '#FFFFFFDD'
			}),
			imgBottom = image({
				pos = T{ 0, 0 }, -- Y pos will be overwritten in code, value here irrelevant
				path = 'assets/xiv/BgBottom.png',
				size = T{ 377, 21 },
				color = '#FFFFFFDD'
			})
		}),

		-- List item - a container for all UI elements of a party member, position is set in code
		listItem = element({
			pos = T{ 0, 0 }, -- overwritten in code

			-- HP bar
			hp = element({
				pos = T{ 19, -7 },
				hideOutsideZone = false,
				hpYellowColor = '#F3F37CFF', -- HP < 75%
				hpOrangeColor = '#F8BA80FF', -- HP < 50%
				hpRedColor = '#FC8182FF', -- HP < 25%
				hpYellowBarColor = '',
				hpOrangeBarColor = '',
				hpRedBarColor = '',
				snapToRaster = true,
				zOrder = 2,

				txtValue = text({
					pos = T{ 120, 35 },
					font = 'Grammara',
					size = 11,
					color = '#F0FFFFFF',
					stroke = '#062D54C8',
					strokeWidth = 2,
					alignRight = true,
					snapToRaster = true
				}),

				bar = element({
					pos = T{ 0, 0 },
					animSpeed = 0.1, -- speed of the bar animation in percent per frame (higher is faster)

					imgBg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarBG.png',
						size = T{ 128, 64 }
					}),
					imgBar = image({
						pos = T{ 13, 0 }, -- centered inside the foreground image = fg.pos + (fg.size - bar.size) / 2
						path = 'assets/xiv/Bar.png',
						size = T{ 102, 64 }
					}),
					imgFg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarFG.png',
						size = T{ 128, 64 }
					}),
					imgGlow = image({
						pos = T{ 13, 0 }, -- centered inside foreground image = bar.pos.y + (bar.size.y - glow.size.y ) / 2, x position set in code
						path = 'assets/xiv/BarGlow.png',
						size = T{ 6, 64 }
					}),
					imgGlowSides = image({
						pos = T{ 11, 0 }, -- x position set in code
						path = 'assets/xiv/BarGlowSides.png',
						size = T{ 2, 64 }
					})
				})
			}),
			-- MP bar
			mp = element({
				pos = T{ 150, -7 },
				hideOutsideZone = false,
				snapToRaster = true,
				zOrder = 3,

				txtValue = text({
					pos = T{ 120, 35 },
					font = 'Grammara',
					size = 11,
					color = '#F0FFFFFF',
					stroke = '#062D54C8',
					strokeWidth = 2,
					alignRight = true,
					snapToRaster = true
				}),

				bar = element({
					pos = T{ 0, 0 },
					animSpeed = 0.1, -- speed of the bar animation in percent per frame (higher is faster)

					imgBg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarBG.png',
						size = T{ 128, 64 }
					}),
					imgBar = image({
						pos = T{ 13, 0 }, -- centered inside the foreground image = fg.pos + (fg.size - bar.size) / 2
						path = 'assets/xiv/Bar.png',
						size = T{ 102, 64 }
					}),
					imgFg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarFG.png',
						size = T{ 128, 64 }
					}),
					imgGlow = image({
						pos = T{ 13, 0 }, -- centered inside foreground image = bar.pos.y + (bar.size.y - glow.size.y ) / 2, x position set in code
						path = 'assets/xiv/BarGlow.png',
						size = T{ 6, 64 }
					}),
					imgGlowSides = image({
						pos = T{ 11, 0 }, -- x position set in code
						path = 'assets/xiv/BarGlowSides.png',
						size = T{ 2, 64 }
					})
				})
			}),
			-- TP bar
			tp = element({
				pos = T{ 281, -7 },
				tpFullColor = '#50B4FAFF', -- TP > 1000
				tpFullBarColor = '',
				hideOutsideZone = false,
				snapToRaster = true,
				zOrder = 4,

				txtValue = text({
					pos = T{ 120, 35 },
					font = 'Grammara',
					size = 11,
					color = '#F0FFFFFF',
					stroke = '#062D54C8',
					strokeWidth = 2,
					alignRight = true,
					snapToRaster = true
				}),

				bar = element({
					pos = T{ 0, 0 },
					animSpeed = 0.1, -- speed of the bar animation in percent per frame (higher is faster)

					imgBg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarBG.png',
						size = T{ 128, 64 }
					}),
					imgBar = image({
						pos = T{ 13, 0 }, -- centered inside the foreground image = fg.pos + (fg.size - bar.size) / 2
						path = 'assets/xiv/Bar.png',
						size = T{ 102, 64 }
					}),
					imgFg = image({
						pos = T{ 0, 0 },
						path = 'assets/xiv/BarFG.png',
						size = T{ 128, 64 }
					}),
					imgGlow = image({
						pos = T{ 13, 0 }, -- centered inside foreground image = bar.pos.y + (bar.size.y - glow.size.y ) / 2, x position set in code
						path = 'assets/xiv/BarGlow.png',
						size = T{ 6, 64 }
					}),
					imgGlowSides = image({
						pos = T{ 11, 0 }, -- x position set in code
						path = 'assets/xiv/BarGlowSides.png',
						size = T{ 2, 64 }
					})
				})
			}),
			-- job icon
			jobIcon = element({
				pos = T{ -11, -2 },
				path = 'assets/jobIcons/', -- where all job icons are located, named <3 letter job>.png
				snapToRaster = true,
				zOrder = 5,

				-- background colors for job roles
				colors = {
					dd = '#663535FF',
					tank = '#364597FF',
					healer = '#3B6529FF',
					support = '#DAB200FF',
					special = '#FF9700FF'
				},

				imgFrame = image({
					pos = T{ 0, 0 },
					path = 'assets/jobIcons/frame.png',
					size = T{ 36, 36 }
				}),
				imgIcon = image({
					pos = T{ 0, 0 },
					path = '', -- must remain empty, set in code
					size = T{ 36, 36 }
				}),
				imgGradient = image({
					pos = T{ 0, 0 },
					path = 'assets/jobIcons/gradient.png',
					size = T{ 36, 36 }
				}),
				imgBg = image({
					pos = T{ 0, 0 },
					path = 'assets/jobIcons/bg.png',
					size = T{ 36, 36 },
					color = '#FFFFFFFF' -- will be overwritten with role colors
				}),
				imgHighlight = image({
					pos = T{ -13, -13 },
					path = 'assets/jobIcons/highlight.png',
					size = T{ 62, 62 }
				})
			}),
			-- leader icons
			leader = element({
				pos = T{ -23, -6 },
				zOrder = 10,

				imgParty = image({
					pos = T{ 0, 0 },
					path = 'assets/xiv/Leader.png',
					size = T{ 22, 22 }
				}),
				imgAlliance = image({
					pos = T{ 0, 11 },
					path = 'assets/xiv/AllianceLeader.png',
					size = T{ 22, 22 }
				}),
				imgQuarterMaster = image({
					pos = T{ 0, 22 },
					path = 'assets/xiv/QuarterMaster.png',
					size = T{ 22, 22 }
				})
			}),
			-- range indicator
			range = element({
				pos = T{ 30, 28.5 },
				zOrder = 11,

				imgNear = image({
					pos = T{ 0, 0 },
					path = 'assets/xiv/Range.png',
					size = T{ 14, 12 }
				}),
				imgFar = image({
					pos = T{ 0, 0 },
					path = 'assets/xiv/RangeFar.png',
					size = T{ 14, 12 }
				}),
				txtDistance = text({
					pos = T{ 0, 1.5 },
					font = 'Grammara',
					size = 6,
					color = '#F0FFFFFF',
					stroke = '#062D54C8',
					strokeWidth = 1,
					snapToRaster = true
				})
			}),
			-- mouse hover image
			hover = image({
				pos = T{ 20, -8 },
				path = 'assets/xiv/Hover.png',
				size = T{ 390, 60 },
				color = '#FFFFFFAA',
				zOrder = 0
			}),
			-- cursor image
			cursor = image({
				pos = T{ 20, -8 },
				path = 'assets/xiv/Cursor.png',
				size = T{ 390, 60 },
				zOrder = 1
			}),
			-- buff icons
			buffIcons = element({
				pos = T{ 293, 0 },
				path = 'libs/status/icons/XIView/', -- directory where buff icons can be found. must follow naming pattern: <buffId>.png
				size = T{ 20, 20 }, -- size of all buff icon images
				color = '#FFFFFFFF', -- color of all buff icon images
				spacing = T{ 0, 1 }, -- spacing between each icon
				numIconsByRow = T{ 19, 13 }, -- number of icons to display in each row (max 32 in total)
				offsetByRow = T{ 0, 6 }, -- offset each row by this many icons to the right
				alignRight = false, -- icons will extend from right to left (adjust pos, x origin will change to the right side!)
				zOrder = 12
			}),
			-- text labels
			txtName = text({
				pos = T{ 95, 1 },
				font = 'Arial',
				size = 15,
				color = '#F0FFFFFF',
				stroke = '#062D54C8',
				strokeWidth = 2,
				maxChars = 17, -- maximum number of characters to display, longer texts will be cut off by replacing the last allowed char with '...'
				snapToRaster = true,
				zOrder = 6
			}),
			txtZone = text({
				pos = T{ 292, 1 },
				font = 'Arial',
				size = 13,
				color = '#F0FFFFFF',
				stroke = '#062D54C8',
				strokeWidth = 2,
				short = false, -- display short zone name
				alignRight = false, -- right align the text to the right end of the TP bar (use short zone names or text might overlap with player name)
				snapToRaster = true,
				zOrder = 7
			}),
			txtJob = text({
				pos = T{ 30, 0 },
				font = 'Arial',
				size = 8,
				color = '#F0FFFFFF',
				stroke = '#062D54C8',
				strokeWidth = 1,
				snapToRaster = true,
				zOrder = 8
			}),
			txtSubJob = text({
				pos = T{ 39, 9 },
				font = 'Arial',
				size = 8,
				color = '#F0FFFFFF',
				stroke = '#062D54C8',
				strokeWidth = 1,
				snapToRaster = true,
				zOrder = 9
			})
		})
	}
}

return layout