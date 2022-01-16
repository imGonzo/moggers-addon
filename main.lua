-- heavily based on https://www.codeproject.com/articles/284961/a-simple-world-of-warcraft-addon-using-lua

local function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end

local function getMogURL()
    local slots = {"HEADSLOT", "SHOULDERSLOT", "SHIRTSLOT", "CHESTSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "WRISTSLOT", "HANDSSLOT", "BACKSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "TABARDSLOT"}
    local fullyQualifiedMogID = {1}

    for realm, characterID in string.gmatch(UnitGUID("player"), "Player%-(%d+)%-(%x+)") do
      fullyQualifiedMogID[#fullyQualifiedMogID+1] = tonumber(realm)
      fullyQualifiedMogID[#fullyQualifiedMogID+1] = tonumber(characterID, 16)
    end

    for i = 1, #slots do
      local transmogLoc = TransmogUtil.CreateTransmogLocation(slots[i], Enum.TransmogType.Appearance, Enum.TransmogModification.None)
      local sourceID = select(3, C_Transmog.GetSlotVisualInfo(transmogLoc))
      local transmogInfo = C_TransmogCollection.GetSourceInfo(sourceID)

      if transmogInfo == nil then
        local invSlot = GetInventorySlotInfo(slots[i])
        itemID = GetInventoryItemID("player", invSlot)
      else
        itemID = transmogInfo.itemID
      end

      if itemID ~= nil then
        fullyQualifiedMogID[#fullyQualifiedMogID + 1] = itemID
      else
        fullyQualifiedMogID[#fullyQualifiedMogID + 1] = 0
      end
    end

    local mogURL = "https://moggers.gg/mog/"

    mogURL = mogURL .. fqmi_to_url(fullyQualifiedMogID)

    return mogURL;
end

local function qrToAscii(v)
    local ok, tab_or_message = qrcode(v)

    if not ok then
        return tab_or_message;
    else
        black_pixel = "█"
        white_pixel = " "
        local rows
        rows = matrix_to_string(tab_or_message,1,white_pixel,white_pixel,black_pixel)

        return table.concat(rows, "\n");
    end
end

Moggers = Moggers or {}

MoggersPerCharDB = MoggersPerCharDB or {
		Frame_myPoint = "CENTER",
		Frame_myRelativePoint = "CENTER",
		Frame_myXOfs = -50,
		Frame_myYOfs = -50
};

Moggers.QR_SIZE = 100;
Moggers.QR_PADDING = 1;

Moggers.frame = CreateFrame("Frame", nil, nil);
Moggers.frame:SetFrameStrata("BACKGROUND");

Moggers.frame:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, ...) end end);

Moggers.frame:RegisterEvent("ADDON_LOADED");
Moggers.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
Moggers.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
Moggers.frame:RegisterEvent("TRANSMOGRIFY_SUCCESS");

UIParent:SetScript("OnHide", function(self, event, ...) Moggers.frame:Show() end);
UIParent:SetScript("OnShow", function(self, event, ...) Moggers.frame:Hide() end);

SLASH_MOGGERS1 = '/moggers';

SlashCmdList["MOGGERS"] = function(msg, editbox)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")

    if cmd and string.lower(cmd) == "show" then
        Moggers.frame:Show();
    elseif cmd and string.lower(cmd) == "hide" then
        Moggers.frame:Hide();
    else
        DEFAULT_CHAT_FRAME:AddMessage("Use Alt+Z to hide the UI and capture a screenshot with the Moggers QR code. Use the left button to position the QR code and the right button to hide it for non-Moggers screen shots.")
    end
end;

function Moggers.frame:ADDON_LOADED(addon)
	if IsLoggedIn() then
		self:PLAYER_LOGIN(true);
	else
		self:RegisterEvent("PLAYER_LOGIN");
	end
end

function Moggers.frame:PLAYER_LOGIN(delayed)

end

function Moggers.frame:PLAYER_EQUIPMENT_CHANGED(delayed)
    Moggers.refresh_qr();
end

function Moggers.frame:TRANSMOGRIFY_SUCCESS(delayed)
    Moggers.refresh_qr();
end

function Moggers.frame:PLAYER_ENTERING_WORLD(delayed)
    self:SetHeight(Moggers.QR_SIZE);
	self:SetWidth(Moggers.QR_SIZE);

	self.texture = self:CreateTexture(nil,"BACKGROUND");
	self.texture:SetAllPoints(self);
	self.texture:SetColorTexture(1.0, 1.0, 1.0, 1.0);

    Moggers.refresh_qr();

    -- self:SetPoint(MoggersPerCharDB.Frame_myPoint, UIParent, MoggersPerCharDB.Frame_myRelativePoint, MoggersPerCharDB.Frame_myXOfs, MoggersPerCharDB.Frame_myYOfs);
    self:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -10, 10);

    self:SetMovable(true);
	self:EnableMouse(true)
	self:RegisterForDrag("LeftButton");
	self:SetScript("OnDragStart", self.OnDragStart);
	self:SetScript("OnDragStop", self.OnDragStop);
    self:SetScript("OnMouseDown", self.OnMouseDown);
    self:Hide();
end

function Moggers.layout_qr()
    local url = getMogURL();
    local ok, qr_data = qrcode(url, 1);

    if not ok then
        return;
    end

    Moggers.qr_squares = Moggers.qr_squares or {};

    local frame = Moggers.frame;
    local square_size = frame:GetWidth()/(#qr_data+Moggers.QR_PADDING*2);
    local row_size = #qr_data[1];

    for x=1,#qr_data do
        for y=1,#(qr_data[x]) do
            local k = x + (y-1) * row_size;

            if not Moggers.qr_squares[k] then
                Moggers.qr_squares[k] = frame:CreateTexture(nil,"ARTWORK");
            end

            local qrs =  Moggers.qr_squares[k];

            qrs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT",
                ((x-1) + Moggers.QR_PADDING) * square_size,
                ((y-1) + Moggers.QR_PADDING) * square_size
            );

            qrs:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT",
                ((x-1) + 1 + Moggers.QR_PADDING) * square_size,
                ((y-1) + 1 + Moggers.QR_PADDING) * square_size
            );
        end
    end

    for k in ipairs(Moggers.qr_squares) do
        Moggers.qr_squares[k]:SetColorTexture(0.0, 0.0, 0.0, 0.0);
    end
end

function Moggers.refresh_qr()
    Moggers.layout_qr();

    local url = getMogURL();
    local ok, qr_data = qrcode(url, 1);

    -- print(url);

    if not ok then
        return;
    end

    local row_size = #qr_data[1];

    -- print("row size", row_size);

    for x=1,#qr_data do
        for y=1,#(qr_data[x]) do
            k = x + (y-1) * row_size;

            if qr_data[x][(row_size+1) - y] > 0 then
                Moggers.qr_squares[k]:SetColorTexture(0.0, 0.0, 0.0, 1.0);
            else
                Moggers.qr_squares[k]:SetColorTexture(0.0, 0.0, 0.0, 0.0);
            end
        end
    end
end

function Moggers.frame:OnDragStart (button)
	-- Debug ("Drag Start");
	self:StartMoving();
end

function Moggers.frame:OnDragStop ()
	-- Debug ("Drag stop");
	self:StopMovingOrSizing();

	-- Save this location in our saved variables for the next time this character
	-- is played.
	local myPoint, myRelativeTo, myRelativePoint, myXOfs, myYOfs = self:GetPoint();
	MoggersPerCharDB.Frame_myPoint = myPoint;
	MoggersPerCharDB.Frame_myRelativeTo = myRelativeTo;
	MoggersPerCharDB.Frame_myRelativePoint = myRelativePoint;
	MoggersPerCharDB.Frame_myXOfs = myXOfs;
	MoggersPerCharDB.Frame_myYOfs = myYOfs ;
end

function Moggers.frame:OnMouseDown (button)
    if button == 'RightButton' then
        self:Hide()
    end
end
