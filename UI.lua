--
-- Tool Hub UI
--

local DEBUGGING_TOOL_HUB = false

-- Helper
		-- Constants
local lp = game:GetService("Players").LocalPlayer
local mouse = lp:GetMouse()
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")

		-- Short OOP lib
local function copytable(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}; for i, v in pairs(tbl) do
		copy[i] = copytable(v)
	end
	return copy
end

local function class(methods, props)
	methods.__index = methods
	
	setmetatable(methods, {
		__call = function(self, ...)
			local obj = setmetatable( copytable(props) or {}, self )
			
			if obj.init then
				obj:init(...)
			end
			
			return obj
		end,
	})
	
	return methods
end
	-- UI helper
local function setProperties(inst, ...)
	local props = {}
	
	for _, def in ipairs({...}) do
		for key, val in pairs(def) do
			props[key] = val
		end
	end
	
	for prop, val in pairs(props) do
		inst[prop] = val
	end
	
	return inst
end

local function new(inst, parent, props, childs)
	inst = Instance.new(inst)
	inst.Parent = parent
	
	setProperties(inst, props)
	for i, v in ipairs(childs or {}) do
		local cn = v[1]
		local cc = v[2] or {}
		v[1] = nil
		v[2] = nil
		new(cn, inst, v, cc)
	end
	
	return inst
end

	-- Events
local Event = class({
	init = function(self)
		self.event = Instance.new("BindableEvent")
	end,
	Fire = function(self, ...)
		self.event:Fire(...)
	end,
	Connect = function(self, func)
		return self.event.Event:Connect(func)
	end,
	Wait = function(self)
		return self.event.Event:Wait()
	end,
}, {
	event = nil,
})

-- create ScreenGui
local SG;
do	
	-- screengui name
	local SG_NAME = "TOOL_HUB"
	
	-- get the parent for the screengui
	local PARENT;
	local SUCCESS = pcall(function()
		PARENT =
			( get_hidden_gui and get_hidden_gui() )
			or
			( game:GetService("CoreGui"):GetChildren() and game:GetService("CoreGui") )
	end)
	if not SUCCESS then
		PARENT = lp:FindFirstChildOfClass("PlayerGui")
	end
	
		-- if debugging delete old screengui
	if DEBUGGING_TOOLHUB and getgenv and getgenv().TOOL_HUB_UI then
		if syn and syn.unprotect_gui then
			pcall(syn.unprotect_gui, TOOL_HUB_UI)
		end
		TOOL_HUB_UI:Destroy()
		getgenv().TOOL_HUB_UI = nil
	end
	
		-- create screengui
	SG = new( "ScreenGui", nil, { Name = SG_NAME, ResetOnSpawn = false } )
	if syn and syn.protect_gui and not DEBUGGING_TOOLHUB then
		syn.protect_gui(SG)
	end
	SG.Parent = PARENT
		--
	
	if DEBUGGING_TOOLHUB and getgenv then
		getgenv().TOOL_HUB_UI = SG
	end
end

-- UI
	-- TabbedFrame component
local TabFrame = class({
	init = function(self, name, tab)
		self.name = name
		self.tabbedFrame = tab
		self.frame = new("Frame", tab.parent, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Name = name,
			Visible = tab.selectedFrame == name,
		})
		
		self.onSelected = Event()
		self.onUnselect = Event()
	end,
	select = function(self)
		self.tabbedFrame:selectTab(self.name)
	end,
	add = function(self, instance)
		instance.Parent = self.frame
		return instance
	end,
}, {
	frame = nil,
	name = "",
	tabbedFrame = nil,
	selected = false,
	
	onSelected = nil,
	onUnselect = nil,
})

local TabbedFrame = class({
	init = function(self, parent)
		self.parent = parent
	end,
	newTab = function(self, name)
		local ins = TabFrame(name, self)
		self.tabs[name] = ins
		
		return ins
	end,
	getTab = function(self, name)
		return self.tabs[name]
	end,
	selectTab = function(self, name)
		local oldTab = self:getTab(self.selectedFrame)
		local newTab = self:getTab(name)
		self.selectedFrame = name
		
		if oldTab then
			oldTab.frame.Visible = false
			oldTab.onUnselect:Fire()
		end
		
		if newTab then
			newTab.frame.Visible = true
			newTab.onSelected:Fire()
		end
	end,
}, {
	parent = nil,
	selectedFrame = "",
	tabs = {},
})
	--
	
	-- Drag Component
local Drag = class({
	init = function(self, trigger, dragged)
		self.trigger = trigger
		self.dragged = dragged
		
		-- make draggable
		self.trigger.InputBegan:Connect(function(triggerInput)
			if triggerInput.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			
			-- start drag
			if self.dragStart then self.dragStart() end
			
			local startOffset = dragged.AbsolutePosition - Vector2.new(mouse.X, mouse.Y)
			self._connection = rs.RenderStepped:Connect(function()
				local pos = Vector2.new(mouse.X, mouse.Y) + startOffset
				dragged.Position = UDim2.fromOffset( pos.X, pos.Y )
				
				if self.whileDrag then self.whileDrag() end
			end)
			
			-- connection to make this stop
			self._stopdrag = uis.InputEnded:Connect(function(dragEndInput)
				if dragEndInput.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
				
				self:stop()
			end)
		end)
	end,
	stop = function(self) -- forces to stop dragging
		if self._connection then self._connection:Disconnect() end
		if self._stopdrag then self._stopdrag:Disconnect() end
		if self.dragEnd then self.dragEnd() end
	end,
}, {
	trigger = nil,
	dragged = nil,
	
	_connection = nil, -- private
	_stopdrag = nil, -- private
	
	whileDrag = nil,
	dragStart = nil,
	dragEnd = nil,
})
	--
	
local ui = (function()
	-- constants
	local c = {}
	c.windowSize = UDim2.fromOffset(400, 200)
	c.topbarSize = 23
	c.leftBarWidth = 120
	
	c.topbarColor = Color3.fromRGB(25, 25, 25)
	c.topbarTextColor = Color3.fromRGB(255, 255, 255)
	c.mainColor = Color3.fromRGB(17, 17, 17)
	c.borderColor = Color3.fromRGB(200, 95, 0)
	c.borderDraggingColor = Color3.fromRGB(1, 72, 144)
	c.tabsBgColor = Color3.fromRGB(20, 20, 20)
	
	c.tabsPaddingTop = 2
	c.tabsPadding = 1
	c.tabsTextSize = 12
	c.tabsSize = UDim2.fromOffset(c.leftBarWidth - 6, 23)
	c.tabsColor = c.tabsBgColor
	c.tabsSelectedColor = c.tabsBgColor
	c.tabsTextColor = Color3.fromRGB(180, 180, 180)
	c.tabsSelectedTextColor = Color3.fromRGB(255, 255, 255)
	c.tabsBorderColor = Color3.fromRGB(95, 95, 95)
	c.tabsSelectedBorderColor = Color3.fromRGB(200, 95, 0)
	c.tabsTweenInfo = TweenInfo.new(0.1)
	
	c.squaresBorderColor = Color3.fromRGB(200, 95, 0)
	c.squaresScrollbarColor = Color3.fromRGB(200, 95, 0)
	c.squaresScrollbarThickness = 4
	
	c.toolIcon = "http://www.roblox.com/asset/?id=6759844130"
	c.minimizeIcon = "http://www.roblox.com/asset/?id=3192533593"
	c.closeIcon = "http://www.roblox.com/asset/?id=3192543734"
	
	c.titleText = "Tool <font color=\"rgb(200, 95, 0)\">Hub</font>"
	
	-- ui
	local u = {}
	u.window = new("Frame", SG, {
		Size = c.windowSize,
		BackgroundTransparency = 1,
		Name = "u.window",
		ClipsDescendants = true,
	})
	
	u.window_childs = new("Frame", u.window, {
		Size = c.windowSize,
		BackgroundTransparency = 1,
		Name = "u.window_childs",
	}, {
		{"UIListLayout",
		SortOrder = "LayoutOrder",
		Name = "layout",
		}
	})
	
		-- topbar
	u.topbar = new("Frame", u.window_childs, {
		Size = UDim2.new(1, 0, 0, c.topbarSize),
		BackgroundTransparency = 1,
		Name = "u.topbar",
	}, {
		{"Frame",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = c.topbarColor,
		Name = "bg",
		}
	})
	
		-- icons at left
	u.topbar_iconsleft = new("Frame", u.topbar, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Name = "u.topbar_iconsleft",
	}, {
		{"UIListLayout",
		FillDirection = "Horizontal",
		SortOrder = "LayoutOrder",
		Name = "layout"
		}
	})
	
			-- tool icon
	u.topbar_icon = new("Frame", u.topbar_iconsleft, {
		Size = UDim2.fromOffset(c.topbarSize, c.topbarSize),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Name = "u.topbar_icon",
	}, {
		{"ImageLabel",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		Image = c.toolIcon,
		Name = "image",
		}
	})
	
			-- title
	u.topbar_title = new("Frame", u.topbar_iconsleft, {
		Size = UDim2.fromOffset(100, c.topbarSize),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Name = "u.topbar_title",
	}, {
		{"TextLabel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = c.titleText,
		TextXAlignment = "Left",
		TextColor3 = c.topbarTextColor,
		RichText = true,
		Name = "text",
			{
				{"UIPadding",
				PaddingLeft = UDim.new(0, 2),
				Name = "padding",
				}
			}
		}
	})
	
		-- icons at right
	u.topbar_iconsright = new("Frame", u.topbar, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Name = "u.topbar_iconsright",
	}, {
		{"UIListLayout",
		FillDirection = "Horizontal",
		SortOrder = "LayoutOrder",
		HorizontalAlignment = "Right",
		Name = "layout",
		}
	})
	
			-- minimize
	u.topbar_minimize = new("TextButton", u.topbar_iconsright, {
		Size = UDim2.fromOffset(c.topbarSize, c.topbarSize),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 0,
		Name = "u.topbar_minimize",
	}, {
		{"ImageLabel",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		Image = c.minimizeIcon,
		Name = "image",
		}
	})
	
			-- close
	u.topbar_close = new("TextButton", u.topbar_iconsright, {
		Size = UDim2.fromOffset(c.topbarSize, c.topbarSize),
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = 1,
		Name = "u.topbar_close",
	}, {
		{"ImageLabel",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		Image = c.closeIcon,
		Name = "image",
		}
	})
	
		-- main
	u.main = new("Frame", u.window_childs, {
		Size = UDim2.new(1, 0, 1, 0 - c.topbarSize),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Name = "u.main",
	}, {
		{"Frame",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = c.mainColor,
		Name = "bg",
		},
		{"Frame",
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = c.borderColor,
		ZIndex = 2,
		Name = "top_border",
		},
	})
	
	u.main_childs = new("Frame", u.main, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Name = "u.main_childs",
	}, {
		{"UIListLayout",
		SortOrder = "LayoutOrder",
		FillDirection = "Horizontal",
		Name = "layout",
		}
	})
	
		-- left bar
	u.leftbar = new("Frame", u.main_childs, {
		Size = UDim2.new(0, c.leftBarWidth, 1, 0),
		BackgroundTransparency = 1,
		Name = "u.leftbar",
	}, {
		{"Frame",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = c.tabsBgColor,
		Name = "bg",
		}
	})
	
		-- main
	u.main_contents = new("Frame", u.main_childs, {
		Size = UDim2.new(1, 0 - c.leftBarWidth, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Name = "u.main_contents",
	})
	
	-- make draggable
	u.drag = Drag(u.topbar, u.window)
	
		-- change border color when drag
	do
		local ai = TweenInfo.new(0.2)
		local border = u.main.top_border
		
		local dragIn = ts:Create(border, ai, {
			BackgroundColor3 = c.borderDraggingColor,
		})
		local dragOut = ts:Create(border, ai, {
			BackgroundColor3 = c.borderColor,
		})
		
		u.drag.dragStart = function()
			dragIn:Play()
		end
		u.drag.dragEnd = function()
			dragOut:Play()
		end
	end
	
	-- make so it can be minimized
	u.minimized = false
	do
		-- create tweens
		local ai = TweenInfo.new(0.2)
		local ai2 = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			-- window size
		local minimizeTween = ts:Create(u.window, ai, {
			Size = UDim2.fromOffset(c.windowSize.X.Offset, c.topbarSize + 1) -- the extra size is the orange border
		})
		local maximizeTween = ts:Create(u.window, ai2, {
			Size = c.windowSize,
		})
			--
		local upTween = ts:Create(u.topbar_minimize.image, ai2, {
			Rotation = 0,
		})
		local downTween = ts:Create(u.topbar_minimize.image, ai, {
			Rotation = 180,
		})
		
		function u:minimize()
			minimizeTween:Play()
			downTween:Play()
			self.minimized = true
		end
		
		function u:maximize()
			maximizeTween:Play()
			upTween:Play()
			self.minimized = false
		end
	end
	
		-- make so it minizes with button
	u.topbar_minimize.Activated:Connect(function()
		if u.minimized then
			u:maximize()
		else
			u:minimize()
		end
	end)
	
	-- make so you can close window
	u.windowClosed = Event()
	
	function u:close()
		if syn and syn.unprotect_gui then
			pcall(syn.unprotect_gui, SG)
		end
		if DEBUGGING_TOOLHUB then
			getgenv().TOOL_HUB_UI = nil
		end
		SG:Destroy()
		
		self.windowClosed:Fire()
	end
	
		-- make close button work
	u.topbar_close.Activated:Connect(function()
		-- create close anim
		local ai = TweenInfo.new(0.2)
		local closeAnim = ts:Create(u.window_childs, ai, {
			AnchorPoint = Vector2.new(1, 0),
		})
		
		-- play close anim
		closeAnim:Play()
		closeAnim.Completed:Wait()
		
		-- close
		u:close()
	end)
	
	-- helpful for making tabs
	u.tabs = (function(parent, constants)
		local obj = {}
		obj.frame = new("Frame", parent, {
			Size = UDim2.fromScale(1, 1),
			Name = "tabs",
			BackgroundTransparency = 1,
		})
		
		obj.tabs = TabbedFrame(obj.frame)
		
			-- selectTab anim
		local playAnim;
		do
			local ai = TweenInfo.new(0.15)
			local goBack = ts:Create(obj.frame, ai, {
				Position = UDim2.fromOffset(0, 0)
			})
			
			playAnim = function()
				obj.frame.Position = UDim2.fromOffset(0, 20)
				goBack:Play()
			end
		end
			--
		
		obj.square = class({
			init = function(self, parent)
				self.square = new("Frame", parent, {
					BackgroundTransparency = 1,
					Name = "squares.square",
				}, {
					{"Frame",
					BackgroundColor3 = constants.mainColor,
					BorderSizePixel = 1,
					BorderColor3 = constants.squaresBorderColor,
					Size = UDim2.fromScale(1, 1),
					Name = "border",
					},
					{"Frame",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Name = "list",
						{
							{"UIListLayout",
							SortOrder = "LayoutOrder",
							Name = "layout",
							},
							{"UIPadding", Name = "padding",},
						},
					}
				})
				
				self:setSize(0) -- :setSize gets defined later
			end,
			setOrder = function(self, order)
				self.square.LayoutOrder = order
			end,
			setSize = function(self, size)
				self.square.Size = UDim2.new(1, 0, 0, size)
			end,
			setListPadding = function(self, padding)
				setProperties(self.square.list.padding, padding)
			end,
			updateSize = function(self)
				local layout = self.square.list.layout
				local padding = self.square.list.padding
				local size = layout.AbsoluteContentSize.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset
				
				self:setSize( size )
			end,
			listAdd = function(self, instance)
				instance.Parent = self.square.list
				return instance
			end,
		}, {
			square = nil,
		})
		
		obj.tab = class({
			init = function(self, name)
				-- create tab
				self.tabObject = obj.tabs:newTab(name)
				
				-- create squares container
				self.squaresContainer = self.tabObject:add( new("ScrollingFrame", nil, {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Name = "tab.squares",
					ScrollBarThickness = constants.squaresScrollbarThickness,
					TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
					BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
					BorderSizePixel = 0,
					ScrollBarImageColor3 = constants.squaresScrollbarColor,
					ScrollingDirection = "Y",
				}, {
					{"UIPadding",
					PaddingLeft = UDim.new(0, 5),
					PaddingRight = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 5),
					Name = "padding",
					},
					{"UIListLayout",
					Padding = UDim.new(0, 5),
					SortOrder = "LayoutOrder",
					Name = "layout",
					}
				} ))
				self:updateScroll() -- :updateScroll gets defined later
			end,
			addSquare = function(self)
				local square = obj.square(self.squaresContainer)
				square:setOrder( self.squares )
				self.squares = self.squares + 1
				
				return square
			end,
			updateScroll = function(self)
				local layout = self.squaresContainer.layout
				local padding = self.squaresContainer.padding
				local size = layout.AbsoluteContentSize.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset
				
				self.squaresContainer.CanvasSize = UDim2.new(1, 0, 0, size)
				
				-- move elements to the left a bit if the scrollbar is showing
				local scrollbarShowing = size > self.squaresContainer.AbsoluteSize.Y
				if scrollbarShowing then
					padding.PaddingRight = UDim.new(0, 5 + self.squaresContainer.ScrollBarThickness)
				end
			end,
		}, {
			tabObject = nil,
			squaresContainer = nil,
			squares = 0,
		})
		
		-- selectTab
		function obj:selectTab(name)
			obj.tabs:selectTab(name)
			playAnim()
		end
		-- newTab
		function obj:newTab(name)
			return self.tab(name)
		end
		
		return obj
	end)(u.main_contents, c)
	
	-- nav bar
	u.navbar = (function(parent, constants)
		local bar = {}
		
		bar.constants = constants
		
		bar.frame = new("Frame", parent, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Name = "navbar"
		}, {
			{"UIListLayout",
			SortOrder = "LayoutOrder",
			HorizontalAlignment = "Center",
			Padding = UDim.new(0, constants.tabsPadding),
			Name = "layout",
			},
			{"UIPadding",
			PaddingTop = UDim.new(0, constants.tabsPaddingTop),
			Name = "padding",
			}
		})
		
		bar.button_class = class({
			init = function(self, name, text, order, constants)
				self.constants = constants
				self.text = text
				self.order = order
				self.name = name
				
				-- create button
				self.frame = new("Frame", bar.frame, {
					BackgroundTransparency = 1,
					Size = constants.tabsSize,
					LayoutOrder = self.order,
					Name = name,
				})
				
				self.button = new("TextButton", self.frame, {
					Size = UDim2.fromScale(1, 1),
					BorderSizePixel = 0,
					Text = self.text,
					Font = "Ubuntu",
					TextSize = constants.tabsTextSize,
					BackgroundColor3 = constants.tabsColor,
					TextColor3 = constants.tabsTextColor,
				})
				
				self.border = new("Frame", self.frame, {
					Size = UDim2.new(1, 0, 0, 1),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					BorderSizePixel = 0,
					BackgroundColor3 = constants.tabsBorderColor,
				})
				
				-- 'activated' event
				self.activated = self.button.Activated
			end,
			select = function(self)
				self.selected = true
				
				-- play anim
				-- get tween
				local textTween, borderTween;
				
				if not self.selectButtonTween then
					local tweenInfo = self.constants.tabsTweenInfo
					
					self.selectButtonTween = ts:Create(self.button, tweenInfo, {
						TextColor3 = self.constants.tabsSelectedTextColor,
						BackgroundColor3 = self.constants.tabsSelectedColor,
					})
					self.selectBorderTween = ts:Create(self.border, tweenInfo, {
						BackgroundColor3 = self.constants.tabsSelectedBorderColor,
					})
				end
				textTween, borderTween = self.selectButtonTween, self.selectBorderTween
				
				-- play
				textTween:Play()
				borderTween:Play()
			end,
			unselect = function(self)
				self.selected = false
				
				-- play anim
				-- get tween
				local textTween, borderTween;
				
				if not self.unselectButtonTween then
					local tweenInfo = self.constants.tabsTweenInfo
					
					self.unselectButtonTween = ts:Create(self.button, tweenInfo, {
						TextColor3 = self.constants.tabsTextColor,
						BackgroundColor3 = self.constants.tabsColor,
					})
					self.unselectBorderTween = ts:Create(self.border, tweenInfo, {
						BackgroundColor3 = self.constants.tabsBorderColor,
					})
				end
				textTween, borderTween = self.unselectButtonTween, self.unselectBorderTween;
				
				-- play
				textTween:Play()
				borderTween:Play()
			end,
		}, {
			frame = nil,
			button = nil,
			order = nil,
			
			activated = nil, -- Event of when the button is clicked
			selected = false,
			text = "",
			order = 0,
			name = "",
		})
		
		bar.buttons = {}
		bar.selectedButton = ""
		
		bar.onSelect = Event()
		function bar:getButton(name)
			for i, v in ipairs(self.buttons) do
				if v.name == name then
					return v
				end
			end
		end
		
		function bar:addButton(name, text)
			local button = self.button_class(name, text, #bar.buttons, self.constants)
			
			--
			button.activated:Connect(function()
				
				-- deselect the other selected button
				local otherButton = self:getButton(self.selectedButton)
					-- check if its not the same button
				if otherButton and otherButton.name == button.name then
					return
				end
					--
				if otherButton then
					otherButton:unselect()
				end
				
				-- select this one
				self.selectedButton = button.name
				button:select()
				
				-- fire
				self.onSelect:Fire(name)
			end)
			
			table.insert( bar.buttons, button )
			
			return button
		end
		
		return bar
	end)(u.leftbar, c)
	
	-- tab system
	function u:newTab(name, text)
		local tab = {}
		tab.button = self.navbar:addButton(name, text)
		tab.tab = self.tabs:newTab(name)
		
		return tab
	end
	
	u.navbar.onSelect:Connect(function(name)
		u.tabs:selectTab(name)
	end)
	
	return u
end)()

--[[
-- usage
local animations = ui:newTab("animations", "Animation")
local dupe = ui:newTab("dupe", "Dupe")

-- animations tab
for i = 1, 10 do
	local square = animations.tab:addSquare()
	local button = square:listAdd( new("TextButton", nil, {Size = UDim2.new(1, 0, 0, 20), BorderSizePixel = 0}))
	square:setListPadding({
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	})
	square:updateSize()
end
animations.tab:updateScroll()

-- dupe tab
for i = 1, 5 do
	local square = dupe.tab:addSquare()
	local label = square:listAdd(new("TextLabel", nil, {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Hello world!",
		Font = "Ubuntu",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 12,
	}))
	square:updateSize()
end
dupe.tab:updateScroll()
]]

return {
	ui = ui;
}
