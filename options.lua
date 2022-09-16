
--[[
##################################INDICATIONS###################################

- Need to copy and paste this (KeyInit() and SetKey()) in your main.lua
- Then put KeyInit() into your init function of main.lua

]]

function KeyInit()

	-- Don't touch this!!!
	SLIDER = 1 -- a slider for an int value
	BUTTON = 2 -- a toggle button
	BIND = 3 -- a button to rebind keys from the keyboard (i.e. not mouse)
	
	-- some extensions to the names. Better to avoid touching this.
	TOGGLE_EXT = "_toggle"
	INF_EXT = "_infinite"
	
	-- modify the keys you are using here
	-- put the correct type (SLIDER, BUTTON, BIND)

	setKey("savegame.mod.slider_key", 20, SLIDER)
	setKey("savegame.mod.button_key", true, BUTTON)
	setKey("savegame.mod.bind_key", 'c', BIND)
end

function setKey(key, default, buttonType)
	
	if not HasKey(key) then
		if buttonType == BUTTON then
			SetBool(key, default)
			
		elseif buttonType == SLIDER then
			SetInt(key, default)
			SetBool(key .. INF_EXT, false)
			
		elseif buttonType == BIND then
			SetString(key, default)
			SetBool(key .. TOGGLE_EXT, false)
		end
	end
end

--------------------------------------------------------------------------------

function init()

	KeyInit()
	dim = {
		w = 0,
		h = 0
	}
end


function draw()
	
	-- Don't touch this!!!
	dim = {
		w = UiWidth(),
		h = UiHeight()
	}
	
	-- Don't touch this!!!
	UiTranslate(UiCenter(), 0)
	UiAlign("center middle")

	-- Don't touch this!!!
	UiTranslate(0, 30)
	UiFont("regular.ttf", 26)
	UiButtonImageBox("ui/common/box-outline-6.png", 6, 6)
	
	
	
	local border = 0.1 * dim.h -- change this float value to increase/decrease the space between the lines
	
	
	UiTranslate(0, border) -- drawing a slider
	DrawIntSlider("savegame.mod.slider_key", 1, 20, 0.4, "Description of slider.", true)
	
	
	UiTranslate(0, border) -- drawing a button
	DrawBoolButton("savegame.mod.button_key", "Description of button.", "Prefix_text: ")
	
	
	UiTranslate(0, border) -- drawing a binding button
	DrawBindButton("savegame.mod.bind_key", "Description of binding button.")
	
	
	
	UiTranslate(0, border + 0.05 * dim.h) -- close button. Pressing "Escape" also close.
	if UiTextButton("Close", 200, 40) then
		Menu()
	end
end

--------------------------------------------------------------------------------

function DrawIntSlider(key, lowerbound, upperbound, sizeScreenRatio, text, infinite)

	-- key: registry key
	-- lowerbound: min integer value
	-- upperbound: max integer value
	-- sizeScreenRatio: ratio of the screen for the size (1 == full width)
	-- text: some description text
	-- infinite: option for sliders only. If true, putting the slider to the max value will write "infinite" instead of the int value.
	-- 			also, the registry "key .. INF_EXT" will be set to true if (value == upperbound), allowing you to know

	local infinite = infinite or false
	local size = sizeScreenRatio * dim.w
	
	if GetInt(key) < lowerbound or GetInt(key) > upperbound then
		SetInt(key, lowerbound)
	end
	
	UiPush()
		UiAlign("center middle")
		UiFont("regular.ttf", 22)
		UiColor(0.9,0.9,0.025,1)
		local value = GetInt(key)
		if GetBool(key .. "_infinite") and infinite then
			value = "Infinite"
		end
		UiText(text .. " " .. value, true)
		UiColor(1,1,1,1)
		UiFont("regular.ttf", 26)
		UiColor(1, 1, 1)
		
		local step = math.floor(size / (upperbound - lowerbound))
		
		UiImageBox("box-solid-6.png", size, 20, 5, 5)
		UiTranslate(-size / 2 - step * lowerbound, 0)
		SetInt(key, math.floor((lowerbound + UiSlider("dot_small.png", "x", GetInt(key) * step, lowerbound * step, upperbound * step)) / step))
		SetBool(key .. "_infinite", GetInt(key) == upperbound)
	UiPop()
end

function DrawBoolButton(key, text, prefix)

	-- key: registry key
	-- text: some description text
	-- prefix: prefix text written on the button

	prefix = prefix or "Toggled: "

	UiPush()
		UiAlign("center middle")
		UiFont("regular.ttf", 22)
		UiColor(0.9,0.9,0.025,1)
		UiText(text, true)
		UiTranslate(0, 15)
		if GetBool(key) then
			UiColor(0,1,0,1)
		else
			UiColor(1,0,0,1)
		end
		UiFont("regular.ttf", 26)
		if UiTextButton(prefix .. tostring(GetBool(key))) then
			SetBool(key, not GetBool(key))
		end
	UiPop()
end

function DrawBindButton(key, text)

	-- key: registry key
	-- text: some description text

	UiPush()
		UiAlign("center middle")
		UiFont("regular.ttf", 22)
		UiColor(0.9,0.9,0.025,1)
		UiText(text, true)
		UiTranslate(0, 15)
		if GetBool(key .. TOGGLE_EXT) then
			UiColor(0,1,0,1)
		else
			UiColor(1,0,0,1)
		end
		UiFont("regular.ttf", 26)
		local keyPressed = InputLastPressedKey()
		local valid = string.match(keyPressed,"[%w]")
		
		if UiTextButton(GetString(key)) then
			SetBool(key .. TOGGLE_EXT, true)
		end
		if GetBool(key .. TOGGLE_EXT) and (valid or keyPressed == "esc") then
				SetBool(key .. TOGGLE_EXT, false)
				if valid and keyPressed ~= "esc" then
					SetString(key, keyPressed)
				end
		end
	UiPop()
end