## Only wipe if the device is not at risk

When *Only wipe if device is not at risk* (`skipWipeIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before any device object is touched. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default and only runs when a wipe is requested; it is skipped when *Do not wipe device* is selected.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the wipe and the selected clean-up actions run as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before the wipe, the exclusion-group membership, the Entra changes and the Intune/Autopilot deletions. A device with an elevated risk score may be involved in a security incident, and wiping it could destroy forensic data (e.g. logs). Align with your security team first; to wipe the device anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the wipe, so devices that are not onboarded to Defender are not blocked.
- **Defender query fails**: the runbook stops without wiping, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every wipe, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "skipWipeIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```

## Add the device to a compliance exclusion group

When *Add device to compliance exclusion group* (`addToExclusionGroup`) is enabled, the wiped Windows device is added to a compliance exclusion group. Devices in that group receive a longer compliance grace period after they are re-enrolled via Autopilot (this mirrors the **Check Device Onboarding Exclusion** runbook).

By default the group is identified by its **display name** (`exclusionGroupName`). Because display names are not guaranteed to be unique, you can instead pin the group by its **Object ID** (`exclusionGroupId`). When an Object ID is provided, it **always overrides** the display name, so name conflicts can never lead to the wrong group being used. `exclusionGroupId` is hidden by default and is meant to be set via runbook customization.

The group is resolved and validated in an upfront preflight check. If the configured group does not exist, the runbook aborts **before** any wipe/delete/disable action, so no half-applied state is left behind. Adding to the group is skipped for non-Windows devices and when the device is deleted from EntraID (`removeAADDevice`).

### Pin the group by Object ID (recommended)

Preset the group's Object ID and enable the switch, keeping the fields hidden. This avoids any ambiguity from duplicate display names.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupId": {
            "Default": "00000000-0000-0000-0000-000000000000",
            "Hide": true
        },
        "exclusionGroupName": {
            "Hide": true
        }
    }
}
```

Replace `00000000-0000-0000-0000-000000000000` with the Object ID of your group (EntraID > Groups > *your group* > **Object Id**).

### Pin the group by display name

If you prefer to work with the display name (and it is unique in your tenant), preset `exclusionGroupName` and leave `exclusionGroupId` empty so the name is used.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupName": {
            "Default": "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
            "Hide": true
        }
    }
}
```
