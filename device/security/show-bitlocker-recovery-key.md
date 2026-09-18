## Only show keys if the device is not at risk

When *Only show keys if device is not at risk* (`skipIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before any recovery key is retrieved. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the recovery keys are shown as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before any key is read. A device with an elevated risk score may be involved in a security incident, and disclosing its recovery key could expose the encrypted data to an attacker. Align with your security team first; to show the keys anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the key retrieval, so devices that are not onboarded to Defender are not blocked.
- **Device found, but without a risk score** (e.g. freshly onboarded): the runbook notes this and proceeds as well.
- **Defender query fails**: the runbook stops without showing any key, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every request, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_security_show-bitlocker-recovery-key": {
    "parameters": {
        "skipIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```
