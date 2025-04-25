--[[
Copyright (C) GtX (Andy), 2018

Author: GtX | Andy
Date: 13.12.2018
Revision: FS25-02

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy/FS25_ServiceVehicle

Important:
Free for use in mods (FS25 Only) - no permission needed.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Frei verwendbar (Nur LS25) - keine erlaubnis nötig
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

ServiceVehicle = {}

ServiceVehicle.MOD_NAME = g_currentModName
ServiceVehicle.SPEC_NAME = string.format("spec_%s.serviceVehicle", g_currentModName)

function ServiceVehicle.prerequisitesPresent(specializations)
    return true
end

function ServiceVehicle.initSpecialization()
    local schema = Vehicle.xmlSchema

    schema:setXMLSpecializationType("ServiceVehicle")

    ServiceVehicleWorkshop.registerXMLPaths(schema, "vehicle.service.workshop")
    ServiceVehicleConsumables.registerXMLPaths(schema, "vehicle.service.consumables")

    schema:register(XMLValueType.BOOL, Dashboard.GROUP_XML_KEY .. "#isServiceEngineStarting", "Is service vehicle consumables engine starting")
    schema:register(XMLValueType.BOOL, Dashboard.GROUP_XML_KEY .. "#isServiceEngineRunning", "Is service vehicle consumables engine running")

    schema:setXMLSpecializationType()

    local schemaSavegame = Vehicle.xmlSchemaSavegame

    schemaSavegame:register(XMLValueType.BOOL, string.format("vehicles.vehicle(?).%s.serviceVehicle.workshop#triggerMarkers", ServiceVehicle.MOD_NAME), "Workshop trigger markers state")
    schemaSavegame:register(XMLValueType.INT, string.format("vehicles.vehicle(?).%s.serviceVehicle.consumables#currentIndex", ServiceVehicle.MOD_NAME), "Consumables current index")
    schemaSavegame:register(XMLValueType.BOOL, string.format("vehicles.vehicle(?).%s.serviceVehicle.consumables#triggerMarkers", ServiceVehicle.MOD_NAME), "Consumables trigger markers state")
end

function ServiceVehicle.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadDashboardGroupFromXML", ServiceVehicle.loadDashboardGroupFromXML)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsDashboardGroupActive", ServiceVehicle.getIsDashboardGroupActive)
end

function ServiceVehicle.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setServiceOperation", ServiceVehicle.setServiceOperation)
    SpecializationUtil.registerFunction(vehicleType, "setServiceTriggerMarkers", ServiceVehicle.setServiceTriggerMarkers)
    SpecializationUtil.registerFunction(vehicleType, "setServiceConsumableType", ServiceVehicle.setServiceConsumableType)
end

function ServiceVehicle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ServiceVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", ServiceVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ServiceVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ServiceVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ServiceVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", ServiceVehicle)
end

function ServiceVehicle:onLoad(savegame)
    self.spec_serviceVehicle = self[ServiceVehicle.SPEC_NAME]

    if self.spec_serviceVehicle == nil then
        g_logManager:error("[%s] Specialization with name 'serviceVehicle' was not found in modDesc!", ServiceVehicle.MOD_NAME)
    end

    local spec = self.spec_serviceVehicle

    local removeNetworking = true
    local removeEventListeners = true

    local workshopKey = "vehicle.service.workshop"

    if self.xmlFile:hasProperty(workshopKey) then
        spec.workshop = ServiceVehicleWorkshop.new(self, true)

        if spec.workshop:onLoad(self.xmlFile, workshopKey, savegame) then
            removeNetworking = not spec.workshop.networkingActive
            removeEventListeners = false
        else
            spec.workshop:onDelete()
            spec.workshop = nil
        end
    end

    local consumablesKey = "vehicle.service.consumables"

    if self.spec_fillUnit ~= nil and self.xmlFile:hasProperty(consumablesKey) then
        spec.consumables = ServiceVehicleConsumables.new(self, false)

        if spec.consumables:onLoad(self.xmlFile, consumablesKey, savegame) then
            if removeNetworking then
                removeNetworking = not spec.consumables.networkingActive
                removeEventListeners = false
            end
        else
            spec.consumables:onDelete()
            spec.consumables = nil
        end
    end

    if removeEventListeners then
        SpecializationUtil.removeEventListener(self, "onUpdate", ServiceVehicle)
        SpecializationUtil.removeEventListener(self, "onFillUnitFillLevelChanged", ServiceVehicle)
    end

    if removeNetworking or removeEventListeners then
        SpecializationUtil.removeEventListener(self, "onReadStream", ServiceVehicle)
        SpecializationUtil.removeEventListener(self, "onWriteStream", ServiceVehicle)
    end
end

function ServiceVehicle:onDelete()
    local spec = self.spec_serviceVehicle

    if spec.workshop ~= nil then
        spec.workshop:onDelete()
        spec.workshop = nil
    end

    if spec.consumables ~= nil then
        spec.consumables:onDelete()
        spec.consumables = nil
    end
end

function ServiceVehicle:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_serviceVehicle

    if spec.workshop ~= nil and spec.workshop.triggerMarkers ~= nil then
        xmlFile:setValue(key .. ".workshop#triggerMarkers", spec.workshop.triggerMarkers.active)
    end

    if spec.consumables ~= nil then
        if spec.consumables.consumablesTypes ~= nil and #spec.consumables.consumablesTypes > 1 then
            xmlFile:setValue(key .. ".consumables#currentIndex", spec.consumables.currentIndex)
        end

        if spec.consumables.triggerMarkers ~= nil then
            xmlFile:setValue(key .. ".consumables#triggerMarkers", spec.consumables.triggerMarkers.active)
        end
    end
end

function ServiceVehicle:onReadStream(streamId, connection)
    if connection:getIsServer() then
        local spec = self.spec_serviceVehicle

        if spec.workshop ~= nil then
            if spec.workshop.operation ~= nil then
                spec.workshop:setOperation(streamReadBool(streamId), true)
            end

            if spec.workshop.triggerMarkers ~= nil then
                spec.workshop:setTriggerMarkers(streamReadBool(streamId), true)
            end
        end

        if spec.consumables ~= nil then
            if spec.consumables.operation ~= nil then
                spec.consumables:setOperation(streamReadBool(streamId), true)
            end

            if spec.consumables.activateInputEnabled then
                spec.consumables:setConsumableType(streamReadUIntN(streamId, ServiceVehicleEvent.SEND_NUM_BITS), false, true)
            end

            if spec.consumables.triggerMarkers ~= nil then
                spec.consumables:setTriggerMarkers(streamReadBool(streamId), true)
            end
        end
    end
end

function ServiceVehicle:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        local spec = self.spec_serviceVehicle

        if spec.workshop ~= nil then
            if spec.workshop.operation ~= nil then
                streamWriteBool(streamId, spec.workshop.operation.active)
            end

            if spec.workshop.triggerMarkers ~= nil then
                streamWriteBool(streamId, spec.workshop.triggerMarkers.active)
            end
        end

        if spec.consumables ~= nil then
            if spec.consumables.operation ~= nil then
                streamWriteBool(streamId, spec.consumables.operation.active)
            end

            if spec.consumables.activateInputEnabled then
                streamWriteUIntN(streamId, spec.consumables.currentIndex, ServiceVehicleEvent.SEND_NUM_BITS)
            end

            if spec.consumables.triggerMarkers ~= nil then
                streamWriteBool(streamId, spec.consumables.triggerMarkers.active)
            end
        end
    end
end

function ServiceVehicle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_serviceVehicle

    if spec ~= nil then
        local raiseActive = false

        if spec.workshop ~= nil and spec.workshop.requiresUpdate then
            raiseActive = spec.workshop:onUpdate(dt)
        end

        if spec.consumables ~= nil and spec.consumables.requiresUpdate then
            raiseActive = spec.consumables:onUpdate(dt) or raiseActive
        end

        if raiseActive then
            self:raiseActive()
        end
    end
end

function ServiceVehicle:onFillUnitFillLevelChanged(fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
    local spec = self.spec_serviceVehicle

    if spec ~= nil and spec.consumables ~= nil and spec.consumables.selectedType ~= nil then
        if spec.consumables:getIsActive() and spec.consumables.selectedType.fillUnitIndex == fillUnitIndex then
            if self:getFillUnitFillLevel(fillUnitIndex) <= 0 then
                spec.consumables:setOperation(false, true)
            end
        end
    end
end

function ServiceVehicle:setServiceOperation(typeId, active, noEventSend)
    local spec = self.spec_serviceVehicle

    if typeId == ServiceVehicleEvent.WORKSHOP_OPERATION then
        if spec.workshop ~= nil then
            spec.workshop:setOperation(active, noEventSend)
        end
    elseif typeId == ServiceVehicleEvent.CONSUMABLES_OPERATION then
        if spec.consumables ~= nil then
            spec.consumables:setOperation(active, noEventSend)
        end
    end
end

function ServiceVehicle:setServiceTriggerMarkers(typeId, active, noEventSend)
    local spec = self.spec_serviceVehicle

    if typeId == ServiceVehicleEvent.WORKSHOP_MARKERS then
        if spec.workshop ~= nil then
            spec.workshop:setTriggerMarkers(active, noEventSend)
        end
    elseif typeId == ServiceVehicleEvent.CONSUMABLES_MARKERS then
        if spec.consumables ~= nil then
            spec.consumables:setTriggerMarkers(active, noEventSend)
        end
    end
end

function ServiceVehicle:setServiceConsumableType(index, force, noEventSend)
    local spec = self.spec_serviceVehicle

    if spec.consumables ~= nil then
        spec.consumables:setConsumableType(index, force, noEventSend)
    end
end

function ServiceVehicle:updateDebugValues(values)
    local spec = self.spec_serviceVehicle

    if spec.workshop ~= nil then
        table.insert(values, {
            name = "Workshop: Number Vehicles",
            value = tostring(#spec.workshop.currentVehicles)
        })
    end

    if spec.consumables ~= nil then
        if spec.consumables.selectedType ~= nil then
            local fillTypeIndex = spec.consumables.selectedType.fillTypeIndex
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

            if fillType ~= nil then
                table.insert(values, {
                    name = "Consumables: Current Type",
                    value = tostring(spec.consumables.selectedType.title) .. " (" .. tostring(fillType.title) .. ")"
                })
            end

            if fillTypeIndex == FillType.ELECTRICCHARGE then
                table.insert(values, {
                    name = "Consumables: Charge Rate",
                    value = tostring(spec.consumables.pumpRate * 60 * 60) .. " kw / hr"
                })
            else
                table.insert(values, {
                    name = "Consumables: Pump Rate",
                    value = tostring(spec.consumables.pumpRate * 60) .. " l / min"
                })
            end
        end

        table.insert(values, {
            name = "Consumables: Engine RPM",
            value = tostring(spec.consumables.engineRpm)
        })

        table.insert(values, {
            name = "Consumables: Engine Load",
            value = tostring(spec.consumables.engineLoad * 100) .. " %"
        })

        table.insert(values, {
            name = "Consumables: Total Filling",
            value = tostring(spec.consumables.numFilling)
        })
    end
end

function ServiceVehicle:loadDashboardGroupFromXML(superFunc, xmlFile, key, group)
    if not superFunc(self, xmlFile, key, group) then
        return false
    end

    group.isServiceEngineStarting = xmlFile:getValue(key .. "#isServiceEngineStarting")
    group.isServiceEngineRunning = xmlFile:getValue(key .. "#isServiceEngineRunning")

    return true
end

function ServiceVehicle:getIsDashboardGroupActive(superFunc, group)
    local spec = self.spec_serviceVehicle

    if spec ~= nil and (group.isServiceEngineStarting or group.isServiceEngineRunning) then
        local operation = spec.consumables ~= nil and spec.consumables.operation

        if operation ~= nil and operation.active then
            if group.isServiceEngineStarting and operation.animationPlaying then
                return true
            end

            if group.isServiceEngineRunning and not operation.animationPlaying then
                return true
            end
        end

        return false
    end

    return superFunc(self, group)
end

--------------------------
-- Service Vehicle Base --
--------------------------

ServiceVehicleBase = {}

local ServiceVehicleBase_mt = Class(ServiceVehicleBase)
local raycastCollisionMask = CollisionFlag.STATIC_OBJECT + CollisionFlag.TERRAIN + CollisionFlag.TERRAIN_DELTA + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.ROAD --[[+ CollisionFlag.VEHICLE]]

function ServiceVehicleBase.registerXMLPaths(schema, baseKey)
    schema:register(XMLValueType.STRING, baseKey .. ".operation#animationName", "Animation name, when provided player trigger is blocked until it is finished playing", nil, true)

    schema:register(XMLValueType.STRING, baseKey .. ".operation#activateText", "The positive direction text (Required if using operation feature)", nil, false)
    schema:register(XMLValueType.STRING, baseKey .. ".operation#deactivateText", "The negative direction text (Required if using operation feature)", nil, false)

    schema:register(XMLValueType.FLOAT, baseKey .. ".operation#openSpeedScale", "Open speed scale", 1, false)
    schema:register(XMLValueType.FLOAT, baseKey .. ".operation#closeSpeedScale", "Close speed scale", "Inverted openSpeedScale", false)

    schema:register(XMLValueType.STRING, baseKey .. ".triggerMarkers#activateText", "The text displayed when deactivated (Required if using markers)", nil, false)
    schema:register(XMLValueType.STRING, baseKey .. ".triggerMarkers#deactivateText", "The text displayed when activated (Required if using markers)", nil, false)
    schema:register(XMLValueType.BOOL, baseKey .. ".triggerMarkers#hideWhenMoving", "Hide all trigger markers when vehicle is moving", false, false)

    schema:register(XMLValueType.NODE_INDEX, baseKey .. ".triggerMarkers.triggerMarker(?)#node", "Trigger marker node")
    schema:register(XMLValueType.NODE_INDEX, baseKey .. ".triggerMarkers.triggerMarker(?)#activeNode", "Optional node used when markers are inactive or hidden", nil, false)
    schema:register(XMLValueType.NODE_INDEX, baseKey .. ".triggerMarkers.triggerMarker(?)#inactiveNode", "Optional node used when markers are inactive or hidden", nil, false)
    schema:register(XMLValueType.INT, baseKey .. ".triggerMarkers.triggerMarker(?)#intensity", "When greater than 0 and a shader with the parameter 'lightControl' is used then the light will be toggled based on trigger activity", 0, false)
    schema:register(XMLValueType.STRING, baseKey .. ".triggerMarkers.triggerMarker(?)#shaderParameter", "Shader parameter", nil, false)
    schema:register(XMLValueType.VECTOR_4, baseKey .. ".triggerMarkers.triggerMarker(?)#shaderOffValues", "Off shader values", "1 0 0 1", false)
    schema:register(XMLValueType.VECTOR_4, baseKey .. ".triggerMarkers.triggerMarker(?)#shaderOnValues", "On shader values", "0 1 0 1", false)
    schema:register(XMLValueType.BOOL, baseKey .. ".triggerMarkers.triggerMarker(?)#adjustToGround", "Links the marker to the ground", false, false)

    schema:register(XMLValueType.NODE_INDEX, baseKey .. "#playerTriggerNode", "Player trigger node", nil, true)
    schema:register(XMLValueType.NODE_INDEX, baseKey .. "#vehicleTriggerNode", "Vehicle trigger node", nil, true)
end

function ServiceVehicleBase.new(vehicle, isWorkshop, customMt)
    local self = setmetatable({}, customMt or ServiceVehicleBase_mt)

    self.isEnabled = true
    self.activateInputEnabled = true

    self.vehicle = vehicle
    self.isWorkshop = isWorkshop

    self.operation = nil
    self.triggerMarkers = nil
    self.networkingActive = false

    self.playerInTrigger = nil
    self.activateText = g_i18n:getText("input_ACTIVATE_OBJECT")

    self.activateActionEventId = nil
    self.operationActionEventId = nil
    self.markersActionEventId = nil

    self.requiresUpdate = false

    return self
end

function ServiceVehicleBase:onLoad(xmlFile, baseKey, savegame)
    self.playerTrigger = xmlFile:getValue(baseKey .. "#playerTriggerNode", nil, self.vehicle.components, self.vehicle.i3dMappings)

    if self.playerTrigger == nil then
        Logging.xmlWarning(xmlFile, "Missing player trigger at '%s#playerTriggerNode'", baseKey)

        return false
    end

    addTrigger(self.playerTrigger, "playerTriggerCallback", self)

    self.vehicleTrigger = xmlFile:getValue(baseKey .. "#vehicleTriggerNode", nil, self.vehicle.components, self.vehicle.i3dMappings)

    if self.vehicleTrigger == nil then
        Logging.xmlWarning(xmlFile, "Missing vehicle trigger at '%s#vehicleTriggerNode'", baseKey)

        return false
    end

    addTrigger(self.vehicleTrigger, "vehicleTriggerCallback", self)

    local animationName = nil

    if self.vehicle.spec_animatedVehicle ~= nil then
        animationName = xmlFile:getValue(baseKey .. ".operation#animationName")
    end

    if animationName ~= nil then
        if InputAction.SV_TOGGLE_OPERATION ~= nil then
            self.operation = {
                active = false,
                animationPlaying = true,
                animationName = animationName,
                activateText = g_i18n:convertText(xmlFile:getValue(baseKey .. ".operation#activateText", "$l10n_button_activate"), ServiceVehicle.MOD_NAME),
                deactivateText = g_i18n:convertText(xmlFile:getValue(baseKey .. ".operation#deactivateText", "$l10n_button_deactivate"), ServiceVehicle.MOD_NAME),
                openSpeedScale = xmlFile:getValue(baseKey .. ".operation#openSpeedScale", 1)
            }

            self.operation.closeSpeedScale = xmlFile:getValue(baseKey .. ".operation#closeSpeedScale", -self.operation.openSpeedScale)

            self.networkingActive = true
            self.requiresUpdate = true
        else
            Logging.xmlWarning(xmlFile, "Unable to register service operation feature, input action 'SV_TOGGLE_OPERATION' is missing from the modDesc.")
        end
    end

    if xmlFile:hasProperty(baseKey .. ".triggerMarkers") then
        if InputAction.SV_TOGGLE_MARKERS ~= nil then
            self.triggerMarkers = {
                markers = {},
                active = false,
                visible = false,
                activateText = g_i18n:convertText(xmlFile:getValue(baseKey .. ".triggerMarkers#activateText", "$l10n_button_activate"), ServiceVehicle.MOD_NAME),
                deactivateText = g_i18n:convertText(xmlFile:getValue(baseKey .. ".triggerMarkers#deactivateText", "$l10n_button_deactivate"), ServiceVehicle.MOD_NAME)
            }

            self.triggerMarkers.hideWhenMoving = xmlFile:getValue(baseKey .. ".triggerMarkers#hideWhenMoving", false)

            xmlFile:iterate(baseKey .. ".triggerMarkers.triggerMarker", function (_, key)
                local node = xmlFile:getValue(key .. "#node", nil, self.vehicle.components, self.vehicle.i3dMappings)

                if node ~= nil then
                    local marker = {
                        node = node,
                        activeNode = node,
                        intensity = xmlFile:getValue(key .. "#intensity", 0), -- Light type shader
                        shaderParameter = xmlFile:getValue(key .. "#shaderParameter") -- Custom shader
                    }

                    local activeNode = xmlFile:getValue(key .. "#activeNode", nil, self.vehicle.components, self.vehicle.i3dMappings)
                    local inactiveNode = xmlFile:getValue(key .. "#inactiveNode", nil, self.vehicle.components, self.vehicle.i3dMappings)

                    if (activeNode ~= nil and activeNode ~= node) and (inactiveNode ~= nil and inactiveNode ~= node) then
                        marker.activeNode = activeNode
                        marker.inactiveNode = inactiveNode
                    end

                    if marker.shaderParameter ~= nil and getHasClassId(node, ClassIds.SHAPE) and getHasShaderParameter(node, marker.shaderParameter) then
                        marker.parameterValues = {
                            [false] = xmlFile:getValue(key .. "#shaderOffValues", "1 0 0 1", true),
                            [true] = xmlFile:getValue(key .. "#shaderOnValues", "0 1 0 1", true)
                        }
                    else
                        marker.shaderParameter = nil
                    end

                    if marker.intensity > 0 and (not getHasClassId(node, ClassIds.SHAPE) or not getHasShaderParameter(node, "lightControl")) then
                        marker.intensity = 0
                    end

                    if xmlFile:getValue(key .. "#adjustToGround", false) then
                        local raycastNode = createTransformGroup(getName(node) .. "_raycastNode")
                        local adjustNode = marker.activeNode

                        link(getParent(adjustNode), raycastNode)
                        setTranslation(raycastNode, getTranslation(adjustNode))
                        setRotation(raycastNode, getRotation(adjustNode))

                        if self.triggerMarkers.adjustToGround == nil then
                            self.triggerMarkers.adjustToGround = {}
                        end

                        table.insert(self.triggerMarkers.adjustToGround, {
                            raycastNode = raycastNode,
                            node = adjustNode,
                            baseTrans = {
                                getTranslation(adjustNode)
                            }
                        })
                    end

                    setVisibility(node, true)

                    table.insert(self.triggerMarkers.markers, marker)
                end
            end)

            self:setTriggerMarkers(true, true)
            self:updateTriggerMarkers(false)

            self.networkingActive = true
            self.requiresUpdate = true
        else
            Logging.xmlWarning(xmlFile, "Unable to register service markers, input action 'SV_TOGGLE_MARKERS' is missing from the modDesc.")
        end
    end

    return true
end

function ServiceVehicleBase:onDelete()
    self.isEnabled = false

    g_animationManager:deleteAnimations(self.animationNodes)

    if self.playerTrigger ~= nil then
        removeTrigger(self.playerTrigger)
        self.playerTrigger = nil
    end

    if self.vehicleTrigger ~= nil then
        removeTrigger(self.vehicleTrigger)
        self.vehicleTrigger = nil
    end

    self.playerInTrigger = nil
    g_currentMission.activatableObjectsSystem:removeActivatable(self)
end

function ServiceVehicleBase:onUpdate(dt)
    local raiseActive = false

    if self.operation ~= nil and self.operation.animationPlaying then
        self.operation.animationPlaying = self.vehicle:getIsAnimationPlaying(self.operation.animationName)

        if self:getIsActiveForInput() then
            self:updateActionEventTexts()
        end

        if not self.operation.animationPlaying then
            self:onAnimationFinished(self.operation.active)
        end

        raiseActive = true
    end

    if self.triggerMarkers ~= nil then
        local triggerMarkers = self.triggerMarkers
        local visible = false

        if not triggerMarkers.hideWhenMoving or self.vehicle.lastSpeed < 0.0001 then
            visible = triggerMarkers.active and self:getIsActive() or false
        end

        if triggerMarkers.visible ~= visible then
            triggerMarkers.visible = visible

            for _, marker in ipairs (self.triggerMarkers.markers) do
                if marker.inactiveNode ~= nil then
                    local linkNode = visible and marker.activeNode or marker.inactiveNode

                    link(linkNode, marker.node)
                else
                    setVisibility(marker.activeNode, visible)
                end
            end
        end

        -- ToDo: Rotate the marker with the ground surface based on size?
        if visible and triggerMarkers.adjustToGround ~= nil then
            local terrainRootNode = g_currentMission.terrainRootNode
            local x, y, z, terrainY, offset, _ = 0, 0, 0, 0, 2, nil

            for _, markers in ipairs (triggerMarkers.adjustToGround) do
                x, y, z = localToWorld(markers.raycastNode, 0, 0, 0)
                terrainY = getTerrainHeightAtWorldPos(terrainRootNode, x, 0, z)

                local objectId, _, hitY, _, _ = RaycastUtil.raycastClosest(x, y + 25, z, 0, -1, 0, 40, raycastCollisionMask)

                if objectId == nil or hitY == nil then
                    hitY = -1
                end

                _, y, _ = worldToLocal(markers.raycastNode, x, math.max(terrainY, hitY), z)

                setTranslation(markers.node, markers.baseTrans[1], y, markers.baseTrans[3])
            end

            raiseActive = true
        end
    end

    return raiseActive
end

function ServiceVehicleBase:setOperation(active, noEventSend)
    if self.operation ~= nil and active ~= nil then
        self.operation.active = active
    end
end

function ServiceVehicleBase:setTriggerMarkers(active, noEventSend)
    if self.triggerMarkers ~= nil and active ~= nil then
        if self.triggerMarkers.active ~= active then
            self.triggerMarkers.active = active

            local typeId = ServiceVehicleEvent.CONSUMABLES_MARKERS

            if self.isWorkshop then
                typeId = ServiceVehicleEvent.WORKSHOP_MARKERS
            end

            ServiceVehicleEvent.sendEvent(self.vehicle, active, typeId, noEventSend)

            local visible = active and self.triggerMarkers.visible

            for _, marker in ipairs (self.triggerMarkers.markers) do
                if marker.inactiveNode ~= nil then
                    local linkNode = visible and marker.activeNode or marker.inactiveNode

                    link(linkNode, marker.node)
                else
                    setVisibility(marker.activeNode, visible)
                end
            end

            self.vehicle:raiseActive()
        end
    end
end

function ServiceVehicleBase:updateTriggerMarkers(vehiclesInTrigger)
    if self.triggerMarkers ~= nil then
        for _, marker in ipairs (self.triggerMarkers.markers) do
            if marker.shaderParameter ~= nil then
                local x, y, z, w = unpack(marker.parameterValues[vehiclesInTrigger])

                setShaderParameter(marker.node, marker.shaderParameter, x, y, z, w, false)
            end

            if marker.intensity > 0 then
                local intensity = vehiclesInTrigger and (1 * marker.intensity) or 0
                local _, y, z, w = getShaderParameter(marker.node, "lightControl")

                setShaderParameter(marker.node, "lightControl", intensity, y, z, w, false)
            end
        end
    end
end

function ServiceVehicleBase:registerCustomInput(inputContext)
    if inputContext ~= PlayerInputComponent.INPUT_CONTEXT_NAME then
        return
    end

    if self.activateInputEnabled then
        local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.ACTIVATE_OBJECT, self, self.onActivateInput, false, true, false, true)

        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
        g_inputBinding:setActionEventTextVisibility(actionEventId, false)

        self.activateActionEventId = actionEventId
    end

    if self.operation ~= nil then
        local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.SV_TOGGLE_OPERATION, self, self.onOperationInput, false, true, false, true)

        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
        g_inputBinding:setActionEventTextVisibility(actionEventId, false)

        self.operationActionEventId = actionEventId
    end

    if self.triggerMarkers ~= nil then
        local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.SV_TOGGLE_MARKERS, self, self.onMarkerInput, false, true, false, true)

        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_HIGH)
        g_inputBinding:setActionEventTextVisibility(actionEventId, false)

        self.markersActionEventId = actionEventId
    end

    self:updateActionEventTexts()
end

function ServiceVehicleBase:removeCustomInput(inputContext)
    g_inputBinding:removeActionEventsByTarget(self)

    self.activateActionEventId = nil
    self.operationActionEventId = nil
    self.markersActionEventId = nil
end

function ServiceVehicleBase:updateActionEventTexts()
    local isActive = self:getIsActive()

    if self.activateActionEventId ~= nil then
        g_inputBinding:setActionEventText(self.activateActionEventId, self.activateText)
        g_inputBinding:setActionEventActive(self.activateActionEventId, isActive)
        g_inputBinding:setActionEventTextVisibility(self.activateActionEventId, isActive)
    end

    if self.operationActionEventId ~= nil then
        g_inputBinding:setActionEventText(self.operationActionEventId, self.operation.active and self.operation.deactivateText or self.operation.activateText)
        g_inputBinding:setActionEventTextVisibility(self.operationActionEventId, true)
    end

    if self.markersActionEventId ~= nil then
        g_inputBinding:setActionEventText(self.markersActionEventId, self.triggerMarkers.active and self.triggerMarkers.deactivateText or self.triggerMarkers.activateText)
        g_inputBinding:setActionEventActive(self.markersActionEventId, isActive)
        g_inputBinding:setActionEventTextVisibility(self.markersActionEventId, isActive)
    end
end

function ServiceVehicleBase:onActivateInput()
end

function ServiceVehicleBase:onOperationInput()
    if self.operation ~= nil then
        self:setOperation(not self.operation.active)
        self:updateActionEventTexts()
    end
end

function ServiceVehicleBase:onMarkerInput()
    if self.triggerMarkers ~= nil then
        self:setTriggerMarkers(not self.triggerMarkers.active)
        self:updateActionEventTexts()
    end
end

function ServiceVehicleBase:onAnimationFinished(active)
end

function ServiceVehicleBase:getIsActive()
    if self.operation ~= nil then
        return self.operation.active and not self.operation.animationPlaying
    end

    return true
end

function ServiceVehicleBase:getIsActiveForInput()
    return self.playerInTrigger == g_localPlayer
end

function ServiceVehicleBase:getHasAccess(farmId)
    return g_currentMission.accessHandler:canFarmAccessOtherId(farmId, self.vehicle:getOwnerFarmId())
end

function ServiceVehicleBase:getDistance(x, y, z)
    if self.isEnabled and self.playerTrigger == nil then
        local tx, ty, tz = getWorldTranslation(self.playerTrigger)

        return MathUtil.vector3Length(x - tx, y - ty, z - tz)
    end

    return math.huge
end

function ServiceVehicleBase:determineCurrentVehicles()
end

function ServiceVehicleBase:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if g_localPlayer ~= nil and otherId == g_localPlayer.rootNode then
            if onEnter then
                if self.playerInTrigger == nil then
                    g_currentMission.activatableObjectsSystem:addActivatable(self)

                    self.playerInTrigger = g_localPlayer
                end
            else
                if self.playerInTrigger ~= nil then
                    g_currentMission.activatableObjectsSystem:removeActivatable(self)

                    self.playerInTrigger = nil
                end
            end

            self:determineCurrentVehicles()
        end
    end
end

function ServiceVehicleBase:vehicleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
end

--------------
-- Workshop --
--------------

ServiceVehicleWorkshop = {}

ServiceVehicleWorkshop.INFO_TEXT_NAMES = {
    "name",
    "extraVehicles",
    "value",
    "age",
    "operatingHours",
    "condition",
    "paintCondition"
}

local ServiceVehicleWorkshop_mt = Class(ServiceVehicleWorkshop, ServiceVehicleBase)

function ServiceVehicleWorkshop.registerXMLPaths(schema, baseKey)
    ServiceVehicleBase.registerXMLPaths(schema, baseKey)

    schema:register(XMLValueType.NODE_INDEX, baseKey.. ".infoTexts#visibilityNode", "Visibility node displayed when any vehicle is in the trigger")

    for _, key in pairs (ServiceVehicleWorkshop.INFO_TEXT_NAMES) do
        local headersKey = baseKey .. ".infoTexts.headers." .. key

        schema:register(XMLValueType.NODE_INDEX, headersKey.. "#node", "Header text node")
        schema:register(XMLValueType.FLOAT, headersKey .. "#textSize", "Header text size", 0.02)
        schema:register(XMLValueType.VECTOR_4, headersKey .. "#textColour", "Header text colour (rgba)", "0.0227 0.5346 0.8519 1.0")

        local valuesKey = baseKey .. ".infoTexts.values." .. key

        schema:register(XMLValueType.NODE_INDEX, valuesKey .. "#node", "Value text node")
        schema:register(XMLValueType.FLOAT, valuesKey .. "#textSize", "Value text size", 0.02)
        schema:register(XMLValueType.VECTOR_4, valuesKey .. "#textColour", "Value text colour (rgba)", "1.0 1.0 1.0 1.0")
    end
end

function ServiceVehicleWorkshop.new(vehicle, isWorkshop)
    local self = ServiceVehicleBase.new(vehicle, isWorkshop, ServiceVehicleWorkshop_mt)

    self.activateText = g_i18n:getText("action_openWorkshopOptions")

    self.vehicleShapesInRange = {}
    self.currentVehicles = {}
    self.infoTexts = {}

    return self
end

function ServiceVehicleWorkshop:onLoad(xmlFile, baseKey, savegame)
    if not ServiceVehicleWorkshop:superClass().onLoad(self, xmlFile, baseKey, savegame) then
        return false
    end

    if xmlFile:hasProperty(baseKey) then
        local infoTexts = {
            name = {
                header = g_i18n:getText("ui_vehicle"):upper(),
                valueFunc = function(object)
                    return object:getFullName()
                end
            },
            extraVehicles = {
                -- No header for this, it is just to show the extra vehicle count
                valueFunc = function(object)
                    if self.currentVehicles ~= nil then
                        local numVehicles = #self.currentVehicles or 0

                        if numVehicles > 1 then
                            return string.format("(+%d)", numVehicles - 1)
                        end
                    end

                    return ""
                end
            },
            value = {
                header = g_i18n:getText("ui_sellValue"):upper(),
                valueFunc = function(object)
                    if object.propertyState == VehiclePropertyState.OWNED and object.getSellPrice ~= nil then
                        return g_i18n:formatMoney(object:getSellPrice(), nil , nil, true)
                    end

                    return "-"
                end
            },
            age = {
                header = g_i18n:getText("ui_age"):upper(),
                valueFunc = function(object)
                    return string.format(g_i18n:getText("shop_age"), (object.age or 0))
                end
            },
            operatingHours = {
                header = g_i18n:getText("ui_operatingHours"):upper(),
                valueFunc = function(object)
                    local minutes = (object.operatingTime or 0) / 60000
                    local hours = math.floor(minutes / 60)

                    return string.format(g_i18n:getText("shop_operatingTime"), hours, math.floor((minutes - hours * 60) / 6))
                end
            },
            condition = {
                header = g_i18n:getText("ui_condition"):upper(),
                valueFunc = function(object)
                    if object.getDamageAmount ~= nil then
                        return string.format("%.0f %%", 100 * (1 - object:getDamageAmount()))
                    end

                    return "100 %"
                end
            },
            paintCondition = {
                header = g_i18n:getText("ui_paintCondition"):upper(),
                valueFunc = function(object)
                    if object.getWearTotalAmount ~= nil then
                        return string.format("%.0f %%", 100 * (1 - object:getWearTotalAmount()))
                    end

                    return "100 %"
                end
            }
        }

        self.infoTextsNode = xmlFile:getValue(baseKey .. ".infoTexts#visibilityNode", nil, self.vehicle.components, self.vehicle.i3dMappings)

        for k, v in pairs (infoTexts) do
            local headerKey = string.format("%s.infoTexts.headers.%s", baseKey, k)
            local valueKey = string.format("%s.infoTexts.values.%s", baseKey, k)

            local headerNode = xmlFile:getValue(headerKey .. "#node", nil, self.vehicle.components, self.vehicle.i3dMappings)
            local valueNode = xmlFile:getValue(valueKey .. "#node", nil, self.vehicle.components, self.vehicle.i3dMappings)

            if (headerNode ~= nil and v.header ~= nil) or valueNode ~= nil then
                table.insert(self.infoTexts, {
                    headerNode = headerNode,
                    valueNode = valueNode,
                    header = v.header,
                    valueFunc = v.valueFunc,
                    headerSize = xmlFile:getValue(headerKey .. "#textSize", 0.04),
                    valueSize = xmlFile:getValue(valueKey .. "#textSize", 0.04),
                    headerColour = xmlFile:getValue(headerKey .. "#textColour", "0.33716 0.55834 0.0003 1", true),
                    valueColour = xmlFile:getValue(valueKey .. "#textColour", "1.0 1.0 1.0 1.0", true)
                })
            end
        end
    end

    if #self.infoTexts > 0 then
        self.requiresUpdate = true
    else
        self.infoTexts = nil
    end

    if savegame ~= nil and self.triggerMarkers ~= nil then
        local triggerMarkersKey = string.format("%s.%s.serviceVehicle.workshop#triggerMarkers", savegame.key, ServiceVehicle.MOD_NAME)

        self:setTriggerMarkers(savegame.xmlFile:getValue(triggerMarkersKey, self.triggerMarkers.active), true)
    end

    return true
end

function ServiceVehicleWorkshop:onUpdate(dt)
    local raiseActive = ServiceVehicleWorkshop:superClass().onUpdate(self, dt)

    if self.infoTexts ~= nil and self:getIsActive() then
        local selectedVehicle = self.currentVehicles[1]

        if g_workshopScreen.isOpen and g_workshopScreen.owner == self then
            selectedVehicle = g_workshopScreen.vehicle or selectedVehicle
        end

        if selectedVehicle ~= nil then
            setTextDepthTestEnabled(true)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
            setTextBold(false)

            for _, text in ipairs (self.infoTexts) do
                ServiceVehicleWorkshop.drawInfoText(text.headerNode, text.header, text.headerColour, text.headerSize)
                ServiceVehicleWorkshop.drawInfoText(text.valueNode, text.valueFunc(selectedVehicle), text.valueColour, text.valueSize)
            end

            setTextColor(1, 1, 1, 1)
            setTextDepthTestEnabled(false)
        end

        raiseActive = true
    end

    return raiseActive
end

function ServiceVehicleWorkshop.drawInfoText(node, text, colour, size)
    if node ~= nil and text ~= nil then
        local x, y, z = getWorldTranslation(node)
        local rx, ry, rz = getWorldRotation(node)

        setTextColor(colour[1], colour[2], colour[3], colour[4])
        renderText3D(x, y, z, rx, ry, rz, size, text)
    end
end

function ServiceVehicleWorkshop:setOperation(active, noEventSend)
    if self.operation ~= nil and active ~= nil then
        if self.operation.active ~= active then
            self.operation.active = active

            ServiceVehicleEvent.sendEvent(self.vehicle, ServiceVehicleEvent.WORKSHOP_OPERATION, active, noEventSend)

            if active then
                self.vehicle:playAnimation(self.operation.animationName, self.operation.openSpeedScale, self.vehicle:getAnimationTime(self.operation.animationName), true)
            else
                self.vehicle:playAnimation(self.operation.animationName, self.operation.closeSpeedScale, self.vehicle:getAnimationTime(self.operation.animationName), true)

                if g_workshopScreen.isOpen and g_workshopScreen.owner == self then
                    g_workshopScreen:onClickBack() -- If another player closes the door then kick all other players
                    g_workshopScreen.owner = nil
                end
            end

            self.operation.animationPlaying = true
            self.vehicle:raiseActive()
        end
    end
end

function ServiceVehicleWorkshop:determineCurrentVehicles()
    local vehicles = {}
    local mission = g_currentMission

    -- New: Check if the player is even part of a farm..
    if mission:getFarmId() ~= FarmManager.SPECTATOR_FARM_ID then
        -- Find first vehicle, then get its root and all children
        for shapeId, inRange in pairs(self.vehicleShapesInRange) do
            if inRange ~= nil and entityExists(shapeId) then
                local vehicle = mission.nodeToObject[shapeId]

                if vehicle ~= nil and vehicle:isa(Vehicle) then
                    local items = vehicle.rootVehicle:getChildVehicles()

                    for _, item in ipairs(items) do
                        -- In base game 'getShowInVehiclesOverview' would be enough,
                        -- but it only takes one mod changing this incorrectly to break the game so some extra checks...
                        if item:getShowInVehiclesOverview() and item.spec_rideable == nil and not vehicle.isPallet then
                            if item ~= self.vehicle and mission.accessHandler:canPlayerAccess(item) then
                                table.addElement(vehicles, item)
                            end
                        end
                    end
                end
            else
                self.vehicleShapesInRange[shapeId] = nil
            end
        end

        -- Consistent order independent on which piece of the vehicle entered the trigger first
        table.sort(vehicles, function(a, b)
            return a.rootNode < b.rootNode
        end)
    end

    self.currentVehicles = vehicles

    local hasVehicles = #vehicles > 0

    if self.infoTextsNode ~= nil then
        setVisibility(self.infoTextsNode, hasVehicles)
    end

    self:updateTriggerMarkers(hasVehicles)

    self.vehicle:raiseActive()

    return vehicles
end

function ServiceVehicleWorkshop:openMenu()
    local vehicles = self:determineCurrentVehicles()

    g_workshopScreen:setSellingPoint(self, false, true, true)
    g_workshopScreen:setVehicles(vehicles)

    g_gui:showGui("WorkshopScreen")
end

function ServiceVehicleWorkshop:onActivateInput()
    self:openMenu()
end

function ServiceVehicleWorkshop:vehicleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if (onEnter or onLeave) and otherShapeId ~= nil then
        if onEnter then
            self.vehicleShapesInRange[otherShapeId] = true
        else
            self.vehicleShapesInRange[otherShapeId] = nil
        end

        local vehicles = self:determineCurrentVehicles()

        if g_workshopScreen.isOpen and g_workshopScreen.owner == self then
            g_workshopScreen:updateVehicles(self, vehicles) -- Update all entering and leaving vehicles only if open
        end
    end
end

-----------------
-- Consumables --
-----------------

ServiceVehicleConsumables = {}

ServiceVehicleConsumables.FILLUNIT = 1
ServiceVehicleConsumables.GENERATOR = 2
ServiceVehicleConsumables.COMPRESSOR = 3

local ServiceVehicleConsumables_mt = Class(ServiceVehicleConsumables, ServiceVehicleBase)

function ServiceVehicleConsumables.registerXMLPaths(schema, baseKey)
    local configKey = baseKey .. ".serviceConsumablesConfigurations.serviceConsumablesConfiguration(?)"

    if g_vehicleConfigurationManager:getConfigurationDescByName("serviceConsumables") == nil then
        g_vehicleConfigurationManager:addConfigurationType("serviceConsumables", g_i18n:getText("configuration_dischargeable"), "service.consumables", VehicleConfigurationItem)
    end

    ServiceVehicleBase.registerXMLPaths(schema, baseKey)

    schema:register(XMLValueType.INT, baseKey .. ".operation.engine#fillUnitIndex", "Engine consumer 'fillUnitIndex', when nil then there is no usage", nil, false)
    schema:register(XMLValueType.FLOAT, baseKey .. ".operation.engine#usagePerSecond", "Default engine consumer usage per second", 0.01, true)

    schema:register(XMLValueType.STRING, configKey .. ".consumablesTypes.consumablesType(?)#variation", "Variation to use. Available Types: fillUnit | generator | compressor", nil, false)

    schema:register(XMLValueType.FLOAT, configKey .. ".consumablesTypes.consumablesType(?)#usagePerSecond", "Engine consumer usage per second when pumping", "Default usage per second", false)
    schema:register(XMLValueType.FLOAT, configKey .. ".consumablesTypes.consumablesType(?)#litersPerSecond", "Litres per second transferred to trigger vehicle", 50)

    schema:register(XMLValueType.INT, configKey .. ".consumablesTypes.consumablesType(?)#fillUnitIndex", "The 'fillUnitIndex' to remove volume from. Only when using variation 'fillUnit'", nil, false)
    schema:register(XMLValueType.STRING, configKey .. ".consumablesTypes.consumablesType(?)#title", "The tile to be displayed when selecting types. Default value is the fill type title", nil, false)

    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, configKey .. ".consumablesTypes.consumablesType(?)")
    ObjectChangeUtil.registerObjectChangeXMLPaths(schema, configKey)

    schema:register(XMLValueType.STRING, baseKey .. ".sharedFillSamples.sharedFillSample(?)#fillTypes", "Fill types that use the give sample when filling")
    SoundManager.registerSampleXMLPaths(schema, baseKey .. ".sharedFillSamples.sharedFillSample(?)", "sample")

    SoundManager.registerSampleXMLPaths(schema, baseKey .. ".operation.sounds", "toggleConsumable(?)")
    SoundManager.registerSampleXMLPaths(schema, baseKey .. ".operation.sounds", "start")
    SoundManager.registerSampleXMLPaths(schema, baseKey .. ".operation.sounds", "stop(?)")
    SoundManager.registerSampleXMLPaths(schema, baseKey .. ".operation.sounds", "work(?)")
    -- SoundManager.registerSampleXMLPaths(schema, baseKey .. ".operation.sounds", "engine(?)")

    schema:register(XMLValueType.NODE_INDEX, baseKey .. ".operation.engine.exhaustEffect#node", "Effect link node")
    schema:register(XMLValueType.STRING, baseKey .. ".operation.engine.exhaustEffect#filename", "Effect i3d filename")
    schema:register(XMLValueType.VECTOR_4, baseKey .. ".operation.engine.exhaustEffect#minLoadColor", "Min. rpm colour", "0 0 0 1")
    schema:register(XMLValueType.VECTOR_4, baseKey .. ".operation.engine.exhaustEffect#maxLoadColor", "Max. rpm colour", "0.0384 0.0359 0.0627 2.0")
    schema:register(XMLValueType.FLOAT, baseKey .. ".operation.engine.exhaustEffect#minLoadScale", "Min. rpm scale", 0.25)
    schema:register(XMLValueType.FLOAT, baseKey .. ".operation.engine.exhaustEffect#maxLoadScale", "Max. rpm scale", 0.95)
    schema:register(XMLValueType.FLOAT, baseKey .. ".operation.engine.exhaustEffect#upFactor", "Defines how far the effect goes up in the air in meter", 0.75)

    Dashboard.registerDashboardXMLPaths(schema, baseKey .. ".operation.dashboards", {"engineRpm", "engineLoad", "pumpRate", "battery", "time", "ignitionState"})
    AnimationManager.registerAnimationNodesXMLPaths(schema, baseKey .. ".operation.animationNodes")
end

function ServiceVehicleConsumables.new(vehicle, isWorkshop)
    local self = ServiceVehicleBase.new(vehicle, isWorkshop, ServiceVehicleConsumables_mt)

    self.consumablesTypes = {}
    self.selectedType = nil
    self.currentIndex = 0

    self.vehiclesToShapeId = {}
    self.fillUnitVehicles = {}

    self.engine = nil
    self.engineLoad = 0
    self.engineRpm = 0

    self.pumpRate = 0
    self.maxPumpRate = 0
    self.numFilling = 0

    self.samples = nil
    self.exhaustEffect = nil

    self.isServer = vehicle.isServer
    self.isClient = vehicle.isClient

    self.customEnvironment = vehicle.customEnvironment
    self.chargeTimeTitle = g_i18n:getText("fillType_electricCharge")
    self.chargeTimeText = "%02d:%02d:%02d ( %s )"

    self.requiresUpdate = true

    return self
end

function ServiceVehicleConsumables:onLoad(xmlFile, baseKey, savegame)
    if not ServiceVehicleConsumables:superClass().onLoad(self, xmlFile, baseKey, savegame) then
        return false
    end

    -- Connect the sound node to the triggers parent
    self.consumablesSoundNode = createTransformGroup("consumablesSoundNode")

    link(getParent(self.vehicleTrigger), self.consumablesSoundNode)
    setTranslation(self.consumablesSoundNode, getTranslation(self.vehicleTrigger))

    local engineFillUnitIndex = xmlFile:getValue(baseKey .. ".operation.engine#fillUnitIndex")
    local defaultUsage = xmlFile:getValue(baseKey .. ".operation.engine#usagePerSecond", 0.01)
    local vehicle = self.vehicle

    if engineFillUnitIndex ~= nil and vehicle:getFillUnitExists(engineFillUnitIndex) then
        self.engine = {
            defaultUsage = defaultUsage,
            fillUnitIndex = engineFillUnitIndex,
            fillTypeIndex = vehicle:getFillUnitFirstSupportedFillType(engineFillUnitIndex)
        }
    end

    local maxNumTypes = 2 ^ ServiceVehicleEvent.TYPE_SEND_NUM_BITS - 1

    local consumablesConfigurationId = Utils.getNoNil(vehicle.configurations.serviceConsumables, 1)
    local consumablesTypesKey = string.format("%s.serviceConsumablesConfigurations.serviceConsumablesConfiguration(%d).consumablesTypes", baseKey, consumablesConfigurationId - 1)

    ObjectChangeUtil.updateObjectChanges(xmlFile, baseKey .. ".serviceConsumablesConfigurations.serviceConsumablesConfiguration", consumablesConfigurationId, vehicle.components, vehicle)

    xmlFile:iterate(consumablesTypesKey .. ".consumablesType", function (_, key)
        local variation = xmlFile:getValue(key .. "#variation", "NONE"):upper()

        if ServiceVehicleConsumables[variation] ~= nil then
            if #self.consumablesTypes >= maxNumTypes then
                Logging.xmlError(xmlFile, "Trying to add too many consumable types. Only %d types are supported", maxNumTypes)

                return false
            end

            variation = ServiceVehicleConsumables[variation]

            local consumablesType = {
                usagePerSecond = math.max(xmlFile:getValue(key .. "#usagePerSecond", defaultUsage), 0.01),
                litersPerSecond = math.min(xmlFile:getValue(key .. "#litersPerSecond", 50), 200),
                infiniteCapacity = false,
                variation = variation
            }

            if variation == ServiceVehicleConsumables.GENERATOR then
                consumablesType.fillTypeIndex = FillType.ELECTRICCHARGE
                consumablesType.infiniteCapacity = true
            elseif variation == ServiceVehicleConsumables.COMPRESSOR then
                consumablesType.fillTypeIndex = FillType.AIR
                consumablesType.infiniteCapacity = true
            else
                consumablesType.fillUnitIndex = xmlFile:getValue(key .. "#fillUnitIndex", 1)
                consumablesType.fillTypeIndex = vehicle:getFillUnitFirstSupportedFillType(consumablesType.fillUnitIndex)
            end

            if consumablesType.fillTypeIndex ~= nil then
                local title = xmlFile:getValue(key .. "#title")

                if title ~= nil then
                    title = g_i18n:convertText(title, ServiceVehicle.MOD_NAME)
                else
                    title = g_fillTypeManager:getFillTypeByIndex(consumablesType.fillTypeIndex).title
                end

                consumablesType.title = string.format(g_i18n:getText("action_workModeSelected"), title)

                consumablesType.objectChanges = {}
                ObjectChangeUtil.loadObjectChangeFromXML(xmlFile, key, consumablesType.objectChanges, vehicle.components, vehicle)

                table.insert(self.consumablesTypes, consumablesType)
            end
        else
            Logging.xmlWarning(xmlFile, "Unknown variation name '%s' given at '%s', this will be ignored.", variation, key)
        end
    end)

    self:setConsumableType(self.currentIndex, true, true)

    self.activateInputEnabled = #self.consumablesTypes > 1

    if self.activateInputEnabled then
        self.networkingActive = true
    end

    if self.selectedType ~= nil then
        if self.isClient then
            xmlFile:iterate(baseKey .. ".sharedFillSamples.sharedFillSample", function (_, key)
                local fillTypeNames = xmlFile:getValue(key .. "#fillTypes")

                if fillTypeNames ~= nil then
                    local fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, "Warning: '" .. vehicle.configFileName .. "' has invalid 'sharedFillSample' fillType '%s'.")

                    if fillTypes ~= nil then
                        local sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sample", vehicle.baseDirectory, vehicle.components, 0, AudioGroup.VEHICLE, vehicle.i3dMappings, self)

                        if sample ~= nil then
                            if self.sharedFillSamples == nil then
                                self.sharedFillSamples = {}
                                self.fillTypeToSample = {}
                            end

                            for _, fillType in pairs(fillTypes) do
                                if self.fillTypeToSample[fillType] == nil then
                                    self.fillTypeToSample[fillType] = sample
                                end
                            end

                            table.insert(self.sharedFillSamples, sample)
                        end
                    end
                else
                    Logging.xmlWarning(xmlFile, "Missing 'fillTypes' for sharedFillSample '%s'", key)
                end
            end)

            local soundsKey = baseKey .. ".operation.sounds"

            self.samples = {
                toggleConsumable = g_soundManager:loadSampleFromXML(xmlFile, soundsKey, "toggleConsumable", vehicle.baseDirectory, vehicle.components, 1, AudioGroup.VEHICLE, vehicle.i3dMappings),
                start = g_soundManager:loadSampleFromXML(xmlFile, soundsKey, "start", vehicle.baseDirectory, vehicle.components, 1, AudioGroup.VEHICLE, vehicle.i3dMappings, self),
                stop = g_soundManager:loadSamplesFromXML(xmlFile, soundsKey, "stop", vehicle.baseDirectory, vehicle.components, 1, AudioGroup.VEHICLE, vehicle.i3dMappings, self),
                work = g_soundManager:loadSamplesFromXML(xmlFile, soundsKey, "work", vehicle.baseDirectory, vehicle.components, 0, AudioGroup.VEHICLE, vehicle.i3dMappings, self)
            }

            -- self.engineSamples = g_soundManager:loadSamplesFromXML(xmlFile, soundsKey, "engine", vehicle.baseDirectory, vehicle.components, 0, AudioGroup.VEHICLE, vehicle.i3dMappings, self, self.engineSamples)

            if self.engine ~= nil then
                local exhaustKey = baseKey .. ".operation.engine.exhaustEffect"
                local filename = xmlFile:getValue(exhaustKey .. "#filename")
                local linkNode = xmlFile:getValue(exhaustKey .. "#node", nil, vehicle.components, vehicle.i3dMappings)

                if filename ~= nil and linkNode ~= nil then
                    filename = Utils.getFilename(filename, vehicle.baseDirectory)

                    local arguments = {
                        xmlFile = xmlFile,
                        key = exhaustKey,
                        linkNode = linkNode,
                        filename = filename
                    }

                    local sharedLoadRequestId = self.vehicle:loadSubSharedI3DFile(filename, false, false, self.onExhaustEffectI3DLoaded, self, arguments)

                    if self.sharedLoadRequestIds == nil then
                        self.sharedLoadRequestIds = {}
                    end

                    if sharedLoadRequestId ~= nil then
                        table.insert(self.sharedLoadRequestIds, sharedLoadRequestId)
                    end
                end
            end

            self.animationNodes = g_animationManager:loadAnimations(xmlFile, baseKey .. ".operation.animationNodes", vehicle.components, vehicle, vehicle.i3dMappings)

            if vehicle.registerDashboardValueType ~= nil then
                local maxRpm = 3000
                local engineRpm = DashboardValueType.new("service", "engineRpm")
                engineRpm:setXMLKey(baseKey .. ".operation.dashboards")
                engineRpm:setValue(self, "engineRpm")
                engineRpm:setRange(0, maxRpm)
                engineRpm:setInterpolationSpeed(function()
                    return maxRpm * 0.001
                end)
                vehicle:registerDashboardValueType(engineRpm)

                local maxLoad = 100
                local engineLoad = DashboardValueType.new("service", "engineLoad")
                engineLoad:setXMLKey(baseKey .. ".operation.dashboards")
                engineLoad:setRange(0, maxLoad)
                engineLoad:setValueFactor(maxLoad)
                engineLoad:setValue(self, function ()
                    return self.engineLoad
                end)
                engineLoad:setInterpolationSpeed(function()
                    return maxLoad * 0.001
                end)
                vehicle:registerDashboardValueType(engineLoad)

                local pumpRate = DashboardValueType.new("service", "pumpRate")
                pumpRate:setXMLKey(baseKey .. ".operation.dashboards")
                pumpRate:setValue(self, "pumpRate")
                pumpRate:setRange(0, self.maxPumpRate)
                pumpRate:setInterpolationSpeed(function()
                    return self.maxPumpRate * 0.001
                end)
                vehicle:registerDashboardValueType(pumpRate)

                local battery = DashboardValueType.new("service", "battery")
                battery:setXMLKey(baseKey .. ".operation.dashboards")
                battery:setRange(0, 15)
                battery:setValue(self, function ()
                    return 12.5 -- + math.random() * 0.5 - 0.15
                end)
                vehicle:registerDashboardValueType(battery)

                local time = DashboardValueType.new("service", "time")
                time:setValue(g_currentMission.environment, "getEnvironmentTime")
                vehicle:registerDashboardValueType(time)

                local ignitionState = DashboardValueType.new("service", "ignitionState")
                ignitionState:setXMLKey(baseKey .. ".operation.dashboards")
                ignitionState:setRange(0, 2)
                ignitionState:setValue(self.operation, function (operation, dashboard)
                    return operation.active and (operation.animationPlaying and 1 or 2) or 0
                end)
                vehicle:registerDashboardValueType(ignitionState)
            end
        end

        if savegame ~= nil and savegame.xmlFile ~= nil then
            local savegameKey = string.format("%s.%s.serviceVehicle", savegame.key, ServiceVehicle.MOD_NAME)
            local xmlFile = savegame.xmlFile

            if self.activateInputEnabled then
                self:setConsumableType(xmlFile:getValue(savegameKey .. ".consumables#currentIndex", self.currentIndex), false, true)
            end

            if self.triggerMarkers ~= nil then
                self:setTriggerMarkers(xmlFile:getValue(savegameKey .. ".consumables#triggerMarkers", self.triggerMarkers.active), true)
            end
        end

        return true
    end

    return false
end

function ServiceVehicleConsumables:onExhaustEffectI3DLoaded(i3dNode, failedReason, args)
    if i3dNode ~= 0 then
        local node = getChildAt(i3dNode, 0)

        if getHasShaderParameter(node, "param") then
            local xmlFile = args.xmlFile
            local key = args.key
            local effect = {
                effectNode = node,
                node = args.linkNode,
                filename = args.filename
            }

            link(effect.node, effect.effectNode)
            setVisibility(effect.effectNode, false)
            delete(i3dNode)

            effect.minRpmColor = xmlFile:getValue(key .. "#minLoadColor", "0 0 0 1", true)
            effect.maxRpmColor = xmlFile:getValue(key .. "#maxLoadColor", "0.0384 0.0359 0.0627 2.0", true)
            effect.minRpmScale = xmlFile:getValue(key .. "#minLoadScale", 0.25)
            effect.maxRpmScale = xmlFile:getValue(key .. "#maxLoadScale", 0.95)
            effect.upFactor = xmlFile:getValue(key .. "#upFactor", 0.75)

            effect.lastPosition = nil
            effect.xRot = 0
            effect.zRot = 0

            self.exhaustEffect = effect
        end
    end
end

function ServiceVehicleConsumables:onDelete()
    ServiceVehicleConsumables:superClass().onDelete(self)

    for vehicle, _ in pairs(self.fillUnitVehicles) do
        if vehicle.removeFillUnitTrigger ~= nil then
            vehicle:removeFillUnitTrigger(self)
            self:setElectricChargeFillActivatableTexts(vehicle.spec_fillUnit, true)
        end

        self.fillUnitVehicles[vehicle] = nil
    end

    if self.progressBars ~= nil then
        for vehicle, progressBar in pairs(self.progressBars) do
            g_currentMission.hud:removeSideNotificationProgressBar(progressBar)
        end

        self.progressBars = nil
    end

    if self.sharedLoadRequestIds ~= nil then
        for _, sharedLoadRequestId in ipairs(self.sharedLoadRequestIds) do
            g_i3DManager:releaseSharedI3DFile(sharedLoadRequestId)
        end

        self.sharedLoadRequestIds = nil
    end

    for _, consumablesType in ipairs(self.consumablesTypes) do
        if consumablesType.fillSample ~= nil then
            g_soundManager:deleteSample(consumablesType.fillSample)

            consumablesType.fillSample = nil
        end
    end

    if self.sharedFillSamples ~= nil then
        for _, sample in pairs(self.sharedFillSamples) do
            g_soundManager:deleteSample(sample)
        end

        self.sharedFillSamples = nil
        self.fillTypeToSample = nil
    end

    g_soundManager:deleteSample(self.fillingSample)

    if self.samples ~= nil then
        g_soundManager:deleteSample(self.samples.toggleConsumable)
        g_soundManager:deleteSample(self.samples.start)
        g_soundManager:deleteSamples(self.samples.stop)
        g_soundManager:deleteSamples(self.samples.work)
        -- g_soundManager:deleteSamples(self.engineSamples)
    end

    g_animationManager:deleteAnimations(self.animationNodes)
end

function ServiceVehicleConsumables:onUpdate(dt)
    local raiseActive = ServiceVehicleConsumables:superClass().onUpdate(self, dt)
    local numFilling = 0

    if self.selectedType ~= nil then
        if self:getIsActive() then
            for vehicle, fillTypeIndex in pairs(self.fillUnitVehicles) do
                local fillTrigger = vehicle.spec_fillUnit.fillTrigger
                local isFilling = fillTrigger ~= nil and fillTrigger.isFilling
                local mission = g_currentMission

                -- If Service vehicle loads after filling vehicle in MP when client joins the trigger will not be loaded try and add here or disable filling (FS22)
                if self.isClient and isFilling and fillTrigger.currentTrigger == nil then
                    for _, trigger in ipairs(fillTrigger.triggers) do
                        if trigger:getIsActivatable(vehicle) then
                            fillTrigger.currentTrigger = trigger

                            if trigger == self then
                                self:setFillSoundIsPlaying(true)
                            end

                            break
                        end
                    end

                    if fillTrigger.currentTrigger == nil then
                        vehicle:setFillUnitIsFilling(false)
                    end
                end

                if isFilling and fillTrigger.currentTrigger == self then
                    if fillTypeIndex == FillType.ELECTRICCHARGE then
                        local controlledVehicle = nil
                        local player = g_localPlayer

                        if player ~= nil then
                            controlledVehicle = player:getCurrentVehicle()
                        end

                        if (controlledVehicle ~= nil and controlledVehicle == vehicle) or self:getIsActiveForInput() then
                            local fillLevel, capacity = 0, 1

                            if vehicle.getConsumerFillUnitIndex ~= nil then
                                local fillUnitIndex = vehicle:getConsumerFillUnitIndex(fillTypeIndex)

                                if fillUnitIndex ~= nil then
                                    fillLevel = vehicle:getFillUnitFillLevel(fillUnitIndex) or 0
                                    capacity = vehicle:getFillUnitCapacity(fillUnitIndex) or 0
                                end
                            end

                            local litersPerSecond = self.selectedType.litersPerSecond

                            if self.numFilling > 1 then
                                litersPerSecond = litersPerSecond / self.numFilling
                            end

                            local remainingTime = (capacity - fillLevel) / litersPerSecond

                            if remainingTime >= 1 then
                                remainingTime = remainingTime / 60

                                if self.progressBars == nil then
                                    self.progressBars = {}
                                end

                                local progressBar = self.progressBars[vehicle]
                                local hours = math.floor(remainingTime / 60)

                                if progressBar == nil then
                                    progressBar = mission.hud:addSideNotificationProgressBar(self.chargeTimeTitle , "", 0)
                                    self.progressBars[vehicle] = progressBar
                                end

                                progressBar.text = string.format(self.chargeTimeText, hours, remainingTime - hours * 60, (remainingTime - math.floor(remainingTime)) * 60, vehicle:getFullName())
                                progressBar.progress = fillLevel / capacity

                                g_currentMission.hud:markSideNotificationProgressBarForDrawing(progressBar)
                            end
                        end
                    end

                    numFilling = numFilling + 1
                end
            end

            if self.engine ~= nil then
                if self.isServer then
                    local usagePerSecond = self.engine.defaultUsage

                    if numFilling > 0 then
                        usagePerSecond = self.selectedType.usagePerSecond or usagePerSecond
                    end

                    local delta = usagePerSecond * 0.001 * (dt or g_currentDt)

                    self.vehicle:addFillUnitFillLevel(self.vehicle:getOwnerFarmId(), self.engine.fillUnitIndex, -delta, self.engine.fillTypeIndex, ToolType.UNDEFINED, nil)
                end

                if self.isClient then
                    if self.exhaustEffect ~= nil then
                        local effect = self.exhaustEffect
                        local posX, posY, posZ = localToWorld(effect.effectNode, 0, 0.5, 0)

                        if effect.lastPosition == nil then
                            effect.lastPosition = {posX, posY, posZ}
                        end

                        local vx = (posX - effect.lastPosition[1]) * 10
                        local vy = (posY - effect.lastPosition[2]) * 10
                        local vz = (posZ - effect.lastPosition[3]) * 10
                        local ex, ey, ez = localToWorld(effect.effectNode, 0, 1, 0)
                        vz = ez - vz
                        vy = ey - vy + effect.upFactor
                        vx = ex - vx

                        local lx, ly, lz = worldToLocal(effect.effectNode, vx, vy, vz)
                        local distance = MathUtil.vector2Length(lx, lz)
                        lx, lz = MathUtil.vector2Normalize(lx, lz)
                        ly = math.abs(math.max(ly, 0.01))

                        local xFactor = math.atan(distance / ly) * (1.2 + 2 * ly)
                        local yFactor = math.atan(distance / ly) * (1.2 + 2 * ly)
                        local xRot = math.atan(lz / ly) * xFactor
                        local zRot = -math.atan(lx / ly) * yFactor
                        effect.xRot = effect.xRot * 0.95 + xRot * 0.05
                        effect.zRot = effect.zRot * 0.95 + zRot * 0.05

                        local engineLoad = self.engineLoad
                        local scale = MathUtil.lerp(effect.minRpmScale, effect.maxRpmScale, engineLoad)

                        setShaderParameter(effect.effectNode, "param", effect.xRot, effect.zRot, 0, scale, false)

                        local r = MathUtil.lerp(effect.minRpmColor[1], effect.maxRpmColor[1], engineLoad)
                        local g = MathUtil.lerp(effect.minRpmColor[2], effect.maxRpmColor[2], engineLoad)
                        local b = MathUtil.lerp(effect.minRpmColor[3], effect.maxRpmColor[3], engineLoad)
                        local a = MathUtil.lerp(effect.minRpmColor[4], effect.maxRpmColor[4], engineLoad)

                        setShaderParameter(effect.effectNode, "exhaustColor", r, g, b, a, false)

                        effect.lastPosition[1] = posX
                        effect.lastPosition[2] = posY
                        effect.lastPosition[3] = posZ
                    end

                    -- local rpmPercentage = math.max(math.min((self.engineRpm - 850) / 1550, 1), 0)
                    -- g_soundManager:setSamplesLoopSynthesisParameters(self.engineSamples, rpmPercentage, self.engineLoad)
                end
            end

            if self.engineRpm == 0 then
                self.engineRpm = 850
            end

            if numFilling > 0 then
                if self.engineLoad < 1 then
                    self.engineLoad = math.min(self.engineLoad + 0.01, 1)
                    self.engineRpm = 850 + (1550 * self.engineLoad)
                    self.pumpRate = math.min(self.maxPumpRate * self.engineLoad, self.maxPumpRate)
                end
            else
                if self.engineLoad > 0 then
                    self.engineLoad = math.max(self.engineLoad - 0.02, 0)
                    self.engineRpm = 850 + (1550 * self.engineLoad)
                    self.pumpRate = 0
                end
            end

            raiseActive = true
        else
            if self.engineLoad > 0 then
                self.engineLoad = math.max(self.engineLoad - 0.02, 0)

                raiseActive = true
            end
        end
    end

    self.numFilling = numFilling

    return raiseActive
end

function ServiceVehicleConsumables:setOperation(active, noEventSend)
    if self.operation ~= nil and active ~= nil then
        if self.operation.active ~= active then
            self.operation.active = active

            ServiceVehicleEvent.sendEvent(self.vehicle, ServiceVehicleEvent.CONSUMABLES_OPERATION, active, noEventSend)

            local animationName = self.operation.animationName
            local samples = self.samples

            if active then
                self.vehicle:playAnimation(animationName, self.operation.openSpeedScale, self.vehicle:getAnimationTime(animationName), true)

                if self.isClient then
                    g_soundManager:stopSample(samples.start)
                    g_soundManager:stopSamples(samples.work)
                    g_soundManager:stopSamples(samples.stop)

                    g_soundManager:playSample(samples.start)
                    -- g_soundManager:playSamples(self.engineSamples, 0, samples.start)

                    for i = 1, #samples.work do
                        g_soundManager:playSample(samples.work[i], 0, samples.start)
                    end

                    if self.exhaustEffect ~= nil then
                        setVisibility(self.exhaustEffect.effectNode, true)
                        setShaderParameter(self.exhaustEffect.effectNode, "param", self.exhaustEffect.xRot, self.exhaustEffect.zRot, 0, 0, false)

                        local color = self.exhaustEffect.minRpmColor

                        setShaderParameter(self.exhaustEffect.effectNode, "exhaustColor", color[1], color[2], color[3], color[4], false)
                    end

                    g_animationManager:startAnimations(self.animationNodes)
                end
            else
                self.vehicle:playAnimation(animationName, self.operation.closeSpeedScale, self.vehicle:getAnimationTime(animationName), true)

                if self.isClient then
                    g_soundManager:stopSample(samples.start)
                    g_soundManager:stopSamples(samples.work)
                    g_soundManager:stopSamples(samples.stop)
                    g_soundManager:playSamples(samples.stop)
                    -- g_soundManager:stopSamples(self.engineSamples)

                    if self.exhaustEffect ~= nil then
                        setVisibility(self.exhaustEffect.effectNode, false)
                    end

                    g_animationManager:stopAnimations(self.animationNodes)

                    if g_soundManager:getIsSamplePlaying(self.fillingSample) then
                        g_soundManager:stopSample(self.fillingSample)
                    end
                end
            end

            self:determineCurrentVehicles()
            self.operation.animationPlaying = true

            self.numFilling = 0
            self.engineRpm = 0
            self.pumpRate = 0

            self.vehicle:raiseActive()
        end
    end
end

function ServiceVehicleConsumables:setConsumableType(index, force, noEventSend)
    if index == nil or self.consumablesTypes[index] == nil then
        index = 1
    end

    if self.currentIndex ~= index or force then
        self.currentIndex = index

        ServiceVehicleEvent.sendEvent(self.vehicle, ServiceVehicleEvent.CONSUMABLES_TYPE, index, noEventSend)

        self.selectedType = self.consumablesTypes[index]
        self.activateText = self.selectedType.title

        self.pumpRate = 0
        self.maxPumpRate = self.selectedType.litersPerSecond

        if self.isClient and self.samples ~= nil then
            g_soundManager:playSample(self.samples.toggleConsumable)
        end

        ObjectChangeUtil.setObjectChanges(self.selectedType.objectChanges, true)

        if self:getIsActiveForInput() then
            self:updateActionEventTexts()
        end

        self:determineCurrentVehicles()

        self.vehicle:raiseActive()
    end
end

function ServiceVehicleConsumables:fillVehicle(vehicle, delta, dt)
    local selectedType = self.selectedType

    if selectedType ~= nil then
        local fillLevel = math.huge
        local farmId = vehicle:getActiveFarm()

        if selectedType.fillUnitIndex ~= nil then
            fillLevel = self.vehicle:getFillUnitFillLevel(selectedType.fillUnitIndex) or 0
        end

        if fillLevel <= 0 or not self:getHasAccess(farmId) then
            return 0
        end

        local fillTypeIndex = selectedType.fillTypeIndex
        local litersPerSecond = selectedType.litersPerSecond

        if self.numFilling > 1 then
            litersPerSecond = litersPerSecond / self.numFilling
        end

        delta = math.min(math.min(delta, litersPerSecond * 0.001 * dt), fillLevel)

        if delta <= 0 then
            return 0
        end

        local fillUnitIndex = vehicle:getFirstValidFillUnitToFill(fillTypeIndex)

        if fillUnitIndex == nil then
            return 0
        end

        delta = vehicle:addFillUnitFillLevel(farmId, fillUnitIndex, delta, fillTypeIndex, ToolType.TRIGGER, nil)

        if delta > 0 and not selectedType.infiniteCapacity then
            self.vehicle:addFillUnitFillLevel(farmId, selectedType.fillUnitIndex, -delta, fillTypeIndex, ToolType.TRIGGER, nil)
        end

        return delta
    end

    return 0
end

function ServiceVehicleConsumables:setFillSoundIsPlaying(isFilling)
    if isFilling then
        local sharedSample = self:getFillSoundSample()

        if sharedSample ~= nil then
            if sharedSample ~= self.sharedSample then
                if self.fillingSample ~= nil then
                    g_soundManager:deleteSample(self.fillingSample)
                end

                self.fillingSample = g_soundManager:cloneSample(sharedSample, self.consumablesSoundNode, self)
                self.sharedSample = sharedSample

                g_soundManager:playSample(self.fillingSample)
            elseif not g_soundManager:getIsSamplePlaying(self.fillingSample) then
                g_soundManager:playSample(self.fillingSample)
            end
        end
    elseif g_soundManager:getIsSamplePlaying(self.fillingSample) then
        local stopSample = true

        for vehicle, fillTypeIndex in pairs(self.fillUnitVehicles) do
            local fillTrigger = vehicle.spec_fillUnit.fillTrigger

            if fillTrigger ~= nil and fillTrigger.isFilling and fillTrigger.currentTrigger == self then
                stopSample = false

                break
            end
        end

        if stopSample then
            g_soundManager:stopSample(self.fillingSample)
        end
    end

    self.vehicle:raiseActive()
end

function ServiceVehicleConsumables:onVehicleDeleted(vehicle)
    self.vehiclesToShapeId[vehicle] = nil
    self.fillUnitVehicles[vehicle] = nil

    self:removeProgressBar(vehicle)

    if self.isClient then
        self:setFillSoundIsPlaying(false)
    end

    self:determineCurrentVehicles()
end

function ServiceVehicleConsumables:getFillSoundSample()
    if self.selectedType ~= nil then
        local fillTypeIndex = self.selectedType.fillTypeIndex

        return self.fillTypeToSample ~= nil and self.fillTypeToSample[fillTypeIndex] or g_fillTypeManager:getSampleByFillType(fillTypeIndex)
    end

    return nil
end

function ServiceVehicleConsumables:getCurrentFillType()
    return self.selectedType ~= nil and self.selectedType.fillTypeIndex or FillType.UNKNOWN
end

function ServiceVehicleConsumables:getIsActivatable(vehicle) -- dirX, dirY, dirZ
    if self.selectedType ~= nil then
        -- TODO: Fix this, it is not elegant at all but solves the issue of clashing functions (getIsActivatable) for FillUnit and ServiceVehicleConsumables
        if vehicle ~= nil and type(vehicle) == "table" and vehicle.getActiveFarm ~= nil then
            if not self:getHasAccess(vehicle:getActiveFarm()) then
                return false
            end

            if self.selectedType.fillUnitIndex ~= nil then
                return (self.vehicle:getFillUnitFillLevel(self.selectedType.fillUnitIndex) or 0) > 0
            end
        end

        return true
    end

    return false
end

function ServiceVehicleConsumables:onActivateInput()
    local index = self.currentIndex + 1

    if index > #self.consumablesTypes then
        index = 1
    end

    self:setConsumableType(index, false)
end

function ServiceVehicleConsumables:onOperationInput()
    if self.operation ~= nil then
        if self.engine ~= nil and self.engine.fillUnitIndex ~= nil then
            local fillUnit = self.vehicle:getFillUnitByIndex(self.engine.fillUnitIndex)

            if fillUnit ~= nil and fillUnit.fillLevel > 0 and fillUnit.capacity ~= 0 then
                self:setOperation(not self.operation.active)
                self:updateActionEventTexts()
            else
                g_currentMission:showBlinkingWarning(g_i18n:getText("info_firstFillTheTool"))
            end
        else
            self:setOperation(not self.operation.active)
            self:updateActionEventTexts()
        end
    end
end

function ServiceVehicleConsumables:onAnimationFinished(active)
    if active then
        self:determineCurrentVehicles()
    end
end

function ServiceVehicleConsumables:removeProgressBar()
    if self.progressBars ~= nil and self.progressBars[vehicle] ~= nil then
        g_currentMission.hud:removeSideNotificationProgressBar(self.progressBars[vehicle])

        self.progressBars[vehicle] = nil

        if next(self.progressBars) == nil then
            self.progressBars = nil
        end
    end
end

function ServiceVehicleConsumables:setElectricChargeFillActivatableTexts(spec, isReset)
    if spec ~= nil and spec.texts ~= nil then
        if isReset then
            if spec.texts.oldStartRefill ~= nil then
                spec.texts.startRefill = spec.texts.oldStartRefill
                spec.texts.oldStartRefill = nil
            end

            if spec.texts.oldStopRefill ~= nil then
                spec.texts.stopRefill = spec.texts.oldStopRefill
                spec.texts.oldStopRefill = nil
            end
        else
            spec.texts.oldStartRefill = spec.texts.startRefill
            spec.texts.oldStopRefill = spec.texts.stopRefill

            spec.texts.startRefill = g_i18n:getText("action_startCharging")
            spec.texts.stopRefill = g_i18n:getText("action_stopCharging")
        end
    end
end

function ServiceVehicleConsumables:determineCurrentVehicles()
    local currentVehicles = {}

    if self.selectedType ~= nil and self:getIsActive() then
        local fillTypeIndex = self.selectedType.fillTypeIndex

        for vehicle, shapeId in pairs(self.vehiclesToShapeId) do
            if shapeId ~= nil and entityExists(shapeId) then
                local fillUnitIndex = vehicle:getFirstValidFillUnitToFill(fillTypeIndex, true)

                if fillUnitIndex ~= nil and self:getHasAccess(vehicle:getOwnerFarmId()) then
                    if self.fillUnitVehicles[vehicle] == nil then
                        self.fillUnitVehicles[vehicle] = fillTypeIndex

                        vehicle:addFillUnitTrigger(self, fillTypeIndex, fillUnitIndex)

                        if fillTypeIndex == FillType.ELECTRICCHARGE then
                            self:setElectricChargeFillActivatableTexts(vehicle.spec_fillUnit, false)
                        end
                    end

                    currentVehicles[vehicle] = shapeId
                end
            else
                self.vehiclesToShapeId[vehicle] = nil
                self.fillUnitVehicles[vehicle] = nil

                self:removeProgressBar(vehicle)
            end
        end
    end

    for vehicle, _ in pairs(self.fillUnitVehicles) do
        if currentVehicles[vehicle] == nil then
            if vehicle.removeFillUnitTrigger ~= nil then
                vehicle:removeFillUnitTrigger(self)
                self:setElectricChargeFillActivatableTexts(vehicle.spec_fillUnit, true)
            end

            self.fillUnitVehicles[vehicle] = nil

            self:removeProgressBar(vehicle)
        end
    end

    self:updateTriggerMarkers(next(self.fillUnitVehicles) ~= nil)
    self.vehicle:raiseActive()

    return self.fillUnitVehicles
end

function ServiceVehicleConsumables:vehicleTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if (onEnter or onLeave) and otherId ~= nil then
        local vehicle = g_currentMission:getNodeObject(otherId)

        if vehicle ~= nil and vehicle ~= self.vehicle and vehicle.getFirstValidFillUnitToFill ~= nil and (vehicle.addFillUnitTrigger ~= nil and vehicle.removeFillUnitTrigger ~= nil) then
            if onEnter then
                if self.vehiclesToShapeId[vehicle] == nil then
                    for _, consumablesType in ipairs(self.consumablesTypes) do
                        if vehicle:getFirstValidFillUnitToFill(consumablesType.fillTypeIndex, true) ~= nil then
                            self.vehiclesToShapeId[vehicle] = otherId

                            break
                        end
                    end
                end
            else
                self.vehiclesToShapeId[vehicle] = nil

                if self.fillUnitVehicles[vehicle] ~= nil and vehicle.removeFillUnitTrigger ~= nil then
                    vehicle:removeFillUnitTrigger(self)
                    self:setElectricChargeFillActivatableTexts(vehicle.spec_fillUnit, true)
                end
            end

            self:determineCurrentVehicles()
        end
    end
end

function ServiceVehicleConsumables:getServiceEngineLoad()
    if self.engine ~= nil then
        return self.engineLoad or 0
    end

    return 0
end

g_soundManager:registerModifierType("SERVICE_ENGINE_LOAD", ServiceVehicleConsumables.getServiceEngineLoad)

function ServiceVehicleConsumables:getServiceEngineRpmReal()
    if self.engine ~= nil then
        return self.engineRpm or 0
    end

    return 0
end

g_soundManager:registerModifierType("SERVICE_ENGINE_RPM_REAL", ServiceVehicleConsumables.getServiceEngineRpmReal)

---------------------------
-- Service Vehicle Event --
---------------------------

ServiceVehicleEvent = {}

ServiceVehicleEvent.WORKSHOP_OPERATION = 0
ServiceVehicleEvent.WORKSHOP_MARKERS = 1
ServiceVehicleEvent.CONSUMABLES_OPERATION = 2
ServiceVehicleEvent.CONSUMABLES_MARKERS = 3
ServiceVehicleEvent.CONSUMABLES_TYPE = 4

ServiceVehicleEvent.SEND_NUM_BITS = 3
ServiceVehicleEvent.TYPE_SEND_NUM_BITS = 3

local ServiceVehicleEvent_mt = Class(ServiceVehicleEvent, Event)
InitEventClass(ServiceVehicleEvent, "ServiceVehicleEvent")

function ServiceVehicleEvent.emptyNew()
    local self = Event.new(ServiceVehicleEvent_mt)

    return self
end

function ServiceVehicleEvent.new(object, typeId, variable)
    local self = ServiceVehicleEvent.emptyNew()

    self.object = object
    self.typeId = typeId
    self.variable = variable

    return self
end

function ServiceVehicleEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.typeId = streamReadUIntN(streamId, ServiceVehicleEvent.SEND_NUM_BITS)

    if self.typeId ~= ServiceVehicleEvent.CONSUMABLES_TYPE then
        self.variable = streamReadBool(streamId)
    else
        self.variable = streamReadUIntN(streamId, ServiceVehicleEvent.TYPE_SEND_NUM_BITS)
    end

    self:run(connection)
end

function ServiceVehicleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.typeId, ServiceVehicleEvent.SEND_NUM_BITS)

    if self.typeId ~= ServiceVehicleEvent.CONSUMABLES_TYPE then
        streamWriteBool(streamId, self.variable)
    else
        streamWriteUIntN(streamId, self.variable, ServiceVehicleEvent.TYPE_SEND_NUM_BITS)
    end
end

function ServiceVehicleEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        if self.typeId == ServiceVehicleEvent.WORKSHOP_OPERATION or self.typeId == ServiceVehicleEvent.CONSUMABLES_OPERATION then
            self.object:setServiceOperation(self.typeId, self.variable, true)
        elseif self.typeId == ServiceVehicleEvent.WORKSHOP_MARKERS or self.typeId == ServiceVehicleEvent.CONSUMABLES_MARKERS then
            self.object:setServiceTriggerMarkers(self.typeId, self.variable, true)
        elseif self.typeId == ServiceVehicleEvent.CONSUMABLES_TYPE then
            self.object:setServiceConsumableType(self.variable, false, true)
        end
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ServiceVehicleEvent.new(self.object, self.typeId, self.variable), nil, connection, self.object)
    end
end

function ServiceVehicleEvent.sendEvent(object, typeId, variable, noEventSend)
    if (noEventSend == nil or noEventSend == false) and object.spec_serviceVehicle ~= nil then
        if g_server ~= nil then
            g_server:broadcastEvent(ServiceVehicleEvent.new(object, typeId, variable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ServiceVehicleEvent.new(object, typeId, variable))
        end
    end
end
