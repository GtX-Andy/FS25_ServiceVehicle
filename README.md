# Service Vehicle Specialisation

 `Farming Simulator  25`&nbsp;&nbsp;&nbsp;&nbsp;`Revision:  FS25-02`&nbsp;&nbsp;&nbsp;&nbsp;`Game Version:  1.4.0.0`

## About
A Farming Simulator 25 vehicle specialisation that provides a workshop trigger and other optional features.

#### &nbsp;&nbsp;&nbsp;&nbsp; - Looking for [FS22_ServiceVehicle](https://github.com/GtX-Andy/serviceVehicle) release?

## Usage
This specialisation is free for use in any Farming Simulator 25 vehicle mod for both ***Private Use*** and ***Public Release***.

## Publishing
The publishing of this specialisation when not included as part of a vehicle mod is not permitted. All links must return to this [GitHub repository](https://github.com/GtX-Andy/FS25_ServiceVehicle).

## Modification / Converting
Only GtX | Andy is permitted to make modifications to this code including but not limited to bug fixes, enhancements or the addition of new features.

Converting this specialisation or parts of it to other version of the Farming Simulator series is not permitted without written approval from GtX | Andy.

## Versioning
All versioning is controlled by GtX | Andy and not by any other page, individual or company.

## Mods Using Spec
[🎁 Field Service Trailer](https://www.farming-simulator.com/mod.php?mod_id=307924&title=fs2025)

> ***Important: The mod listed above can be enjoyed while playing Farming Simulator 25 or as a reference of how the available features can be used in your own mod. The dismantling of this mod or the removal of any parts for use on other publicly released mods is strictly prohibited without written approval from GtX | Andy***

## Documentation
Not all features used in the above listed mod are required when creating your own mods. The service script can operate with just a `Vehicle Trigger` and `Player Trigger` as shown below.

>### vehicle.xml

```xml
<vehicle type="myServiceVehicle" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../../../shared/xml/schema/vehicle.xsd">
    <service>
        <workshop playerTriggerNode="sellTrigger" vehicleTriggerNode="sellAreaTrigger" />
    </service>
</vehicle>
```
>### modDesc.xml

```xml
<modDesc>
    <specializations>
        <specialization name="serviceVehicle" className="ServiceVehicle" filename="scripts/ServiceVehicle.lua"/>
    </specializations>

    <vehicleTypes>
        <type name="myServiceVehicle" parent="baseFillable" className="Vehicle" filename="$dataS/scripts/vehicles/Vehicle.lua">
            <specialization name="serviceVehicle"/>
        </type>
    </vehicleTypes>
</modDesc>
```

## Copyright
Copyright (c) 2018 [GtX (Andy)](https://github.com/GtX-Andy)
