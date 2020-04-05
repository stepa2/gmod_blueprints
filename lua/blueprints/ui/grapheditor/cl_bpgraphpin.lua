if SERVER then AddCSLuaFile() return end

module("bpuigraphpin", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect
local math_ceil = math.ceil

local meta = bpcommon.MetaTable("bpuigraphpin")

local TEXT_OFFSET = 8
local LITERAL_OFFSET = 10
local LITERAL_HEIGHT = 24
local LITERAL_MIN_WIDTH = 40
local LITERAL_MAX_WIDTH = 350
local PIN_SIZE = 24
local PIN_HITBOX_EXPAND = 8
local PIN_LITERAL_HITBOX_EXPAND = 8

function meta:Init(vnode, pinID, sideIndex)

	self.x = 0
	self.y = 0
	self.currentPinType = nil
	self.pinID = pinID
	self.vnode = vnode
	self.pin = vnode:GetNode():GetPin(pinID)
	self.sideIndex = sideIndex
	self.font = "NodePinFont"
	self.literalFont = "NodeLiteralFont"
	self.titlePos = nil
	self.literalPos = nil
	self.cacheWidth = nil
	self.cacheHeight = nil
	self.connections = self.pin:GetConnectedPins()
	self.invalidateMetrics = true

	return self

end

function meta:GetDisplayName()

	if self.displayName then return self.displayName end

	local str = bpcommon.Camelize(self.pin:GetDisplayName()):gsub("%u", function(x) return " " .. x end)
	if #str > 0 then str = str:sub(2, -1) end
	self.displayName = str
	return self.displayName

end

function meta:GetConnections()

	return self.connections

end

function meta:GetVNode()

	return self.vnode

end

function meta:GetSideIndex()

	return self.sideIndex

end

function meta:GetPinID()

	return self.pinID

end

function meta:GetPin()

	return self.pin

end

function meta:GetPos()

	return self.x, self.y

end

function meta:SetPos(x,y)

	self.x = x
	self.y = y

end

function meta:GetLiteralSize()

	if self.literalW and self.literalH then return self.literalW, self.literalH end

	if not self:ShouldDrawLiteral() then return 0,0 end

	local literalType = self.pin:GetLiteralType()
	local h = LITERAL_HEIGHT
	local w = LITERAL_MIN_WIDTH

	local pin = self:GetPin()
	if pin.GetLiteralSize then
		w,h = pin:GetLiteralSize(h)
	else

		local display = self.pin.GetLiteralDisplay and self.pin:GetLiteralDisplay() or nil
		local font = self.literalFont
		surface.SetFont(font)

		local value = display or self:GetLiteralValue()
		w = surface.GetTextSize(value)

		w,h = math.Clamp( w, LITERAL_MIN_WIDTH, LITERAL_MAX_WIDTH ), h

	end

	self.literalW, self.literalH = w, h

	return w, h

end

function meta:ShouldDrawLiteral()

	if not self:IsConnected() and not self.pin:HasFlag(PNF_Table) then
		if self.pin:GetDir() == PD_In and self.pin:CanHaveLiteral() then
			return self:GetVNode():GetNode():GetTypeName() ~= "CORE_Pin"
		end
	end
	return false

end

function meta:Invalidate()

	self.cacheWidth = nil
	self.cacheHeight = nil
	self.titlePos = nil
	self.literalPos = nil
	self.literalText = nil
	self.connections = self.pin:GetConnectedPins()
	self.invalidateMetrics = true
	self.literalW = nil
	self.literalH = nil
	self.connectionState = nil
	self.displayName = nil

end

function meta:GetSize()

	if self.cacheWidth and self.cacheHeight then 
		return self.cacheWidth, self.cacheHeight 
	end

	local width = PIN_SIZE
	local height = PIN_SIZE
	local node = self.vnode:GetNode()

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		surface.SetFont( self.font )
		local title = self:GetDisplayName()
		local titleWidth = surface.GetTextSize( title )
		width = width + titleWidth + TEXT_OFFSET
	end

	if self:ShouldDrawLiteral() then
		local lw, lh = self:GetLiteralSize()
		width = width + LITERAL_OFFSET + lw
		height = math.max(height, lh)
	end

	self.cacheWidth = width
	self.cacheHeight = height

	return width, height

end

function meta:Layout()

	if self.titlePos and self.literalPos then return end

	local node = self.vnode:GetNode()
	local w,h = self:GetSize()
	local x = 0
	local d = 1
	if self.pin:IsOut() then
		x = w
		d = -1
	end

	x = x + PIN_SIZE * d

	surface.SetFont( self.font )

	self.titlePos = 0
	self.literalPos = 0

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		local title = self:GetDisplayName()
		local titleWidth = surface.GetTextSize( title )
		x = x + TEXT_OFFSET * d
		if self.pin:IsOut() then x = x + titleWidth * d end
		self.titlePos = x
		x = x + titleWidth * d
	end

	if self.pin:IsIn() then
		self.autoPin = node:GetModule():AutoFillsPinType( self.pin:GetType() )
	end
	if not self:IsConnected() then
		self.literalPos = LITERAL_OFFSET + x
	else
		self.autoPin = false
	end

end

function meta:GetHotspotOffset()

	local w,h = self:GetSize()
	if self.pin:IsIn() then
		return PIN_SIZE/2, PIN_SIZE/2 + (h - PIN_SIZE)/2
	else
		local w,h = self:GetSize()
		return w-PIN_SIZE/2, PIN_SIZE/2 + (h - PIN_SIZE)/2
	end

end

function meta:GetHitBox()

	local nx,ny = self.vnode:GetPos()
	local x,y = self:GetPos()
	local w,h = PIN_SIZE, PIN_SIZE
	local hx,hy = self:GetHotspotOffset()
	local ex = PIN_HITBOX_EXPAND
	return nx+x+hx-PIN_SIZE/2-ex/2,ny+y+hy-PIN_SIZE/2-ex/2,w+ex,h+ex

end

function meta:GetLiteralHitBox()

	self:Layout()
	if self:ShouldDrawLiteral() then
		local ex = PIN_LITERAL_HITBOX_EXPAND
		local nx,ny = self.vnode:GetPos()
		local x,y = self:GetPos()
		local lw, lh = self:GetLiteralSize()

		return x+nx+self.literalPos-ex/2,y+ny-ex/2,lw+ex,lh+ex
	end

	return 0,0,0,0

end

function meta:IsConnected()

	if self.connectionState ~= nil then return self.connectionState end

	local node = self.vnode:GetNode()
	local graph = node:GetGraph()
	self.connectionState = graph:IsPinConnected( node.id, self.pinID )

	return self.connectionState

end

function meta:GetLiteralValue()

	if self.literalText then return self.literalText end

	local node = self.vnode:GetNode()
	local literalType = self.pin:GetLiteralType()
	if not literalType then return "" end

	local literal = node:GetLiteral(self.pinID) or "!!!UNASSIGNED LITERAL!!!"

	self.literalText = bpcommon.ZipStringLeft(tostring(literal), 26)

	return literal

end

function meta:DrawLiteral(x, y, alpha)

	local node = self.vnode:GetNode()
	local font = self.literalFont
	if self.pin:GetDir() == PD_In and not self.pin:HasFlag(PNF_Table) then
		if self.pin:CanHaveLiteral() and self:ShouldDrawLiteral() then
			local display = self.pin.GetLiteralDisplay and self.pin:GetLiteralDisplay() or nil
			local literal = display or self:GetLiteralValue()

			local w, h = self:GetLiteralSize()

			if self.pin.DrawLiteral then

				self.pin:DrawLiteral(x + self.literalPos,y,w,h,alpha)

			else

				surface_setDrawColor( 50,50,50,150*alpha )
				surface_drawRect(x + self.literalPos,y,w,h)

				surface_setFont( font )
				surface_setTextPos( math_ceil( x + self.literalPos ), math_ceil( y+(PIN_SIZE - LITERAL_HEIGHT - 2)/2 ) )
				surface_setTextColor( 255, 255, 255, 255*alpha )
				surface_drawText( literal )

			end

		end
	end

	--surface.SetDrawColor( Color(255,255,255) )
	--surface.DrawRect(x,y,10,10)

end

function meta:DrawHotspot(x,y,alpha)

	if self.pin:IsType(PN_Dummy) then return end

	local ox, oy = self:GetHotspotOffset()
	local isTable = self.pin:HasFlag(PNF_Table)
	local r,g,b,a = self.pin:GetColor():Unpack()

	surface_setDrawColor( r, g, b, 255 * alpha )
	surface_drawRect(x+ox-PIN_SIZE/2,y+oy-PIN_SIZE/2,PIN_SIZE,PIN_SIZE)

	if isTable then
		surface_setDrawColor( 0,0,0,255 )
		surface_drawRect(x+ox - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
		surface_drawRect(x+ox+PIN_SIZE*.25 - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
		surface_drawRect(x+ox-PIN_SIZE*.25 - 2,y+oy-PIN_SIZE/2,4,PIN_SIZE)
	end

	if self.autoPin then

		surface_setDrawColor( 0,0,0,250 )
		surface_drawRect(x+ox-PIN_SIZE/2 + 5,y+oy-PIN_SIZE/2 + 5,PIN_SIZE-10,PIN_SIZE-10)

	end

end

function meta:DrawHitBox()

	local hx,hy,hw,hh = self:GetLiteralHitBox()
	surface_setDrawColor( 255,100,200,80 )
	surface_drawRect(hx,hy,hw,hh)

end

function meta:BuildMetrics()

	if self.invalidateMetrics ~= nil and not self.invalidateMetrics then return end

	local title = self:GetDisplayName()

	surface.SetFont(self.font)
	self.titleWidth, self.titleHeight = surface.GetTextSize( title )
	self.invalidateMetrics = false

end

function meta:Draw(xOffset, yOffset, alpha)

	if self.currentPinType == nil or not self.currentPinType:Equal(self.pin:GetType()) then
		self:Invalidate()
		self.currentPinType = bpcommon.CopyTable( self.pin:GetType() )
		self.vnode:Invalidate()
		--print("PIN TYPE CHANGED")
	end

	self:Layout()
	self:BuildMetrics()

	local x,y = self:GetPos()
	local w,h = self:GetSize()
	local ox, oy = self:GetHotspotOffset()
	local node = self.vnode:GetNode()
	local font = self.font

	x = x + xOffset
	y = y + yOffset

	self:DrawHotspot(x,y,alpha)

	--render.PushFilterMag( TEXFILTER.LINEAR )
	--render.PushFilterMin( TEXFILTER.LINEAR )

	if not self:IsConnected() then self:DrawLiteral(x,y,alpha) end

	--self:DrawHitBox()

	local title = self:GetDisplayName()

	if not node:HasFlag(NTF_Compact) and not node:HasFlag(NTF_HidePinNames) then
		local hx,hy = self:GetHotspotOffset()
		surface_setFont( self.font )
		surface_setTextPos( math_ceil( x + self.titlePos ), math_ceil( hy + y-(self.titleHeight)/2 ) )
		surface_setTextColor( self.autoPin and 40 or 255, self.autoPin and 220 or 255, 255, 255*alpha )
		surface_drawText( title )
	end

	--render.PopFilterMag()
	--render.PopFilterMin()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end