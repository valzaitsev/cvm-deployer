package policy
import rego.v1

# Default to denying access
default allow := false

# Allow access ONLY if the GPU and CPU conditions are met:
allow if {
    #
    # GPU
    #

    # The NVIDIA GPU must pass attestation
    input["submods"]["gpu0"]["ear.status"] == "affirming"

    # Inspect the annotated hardware evidence for the GPU
    gpu := input["submods"]["gpu0"]["ear.veraison.annotated-evidence"]["nvidia"]

    # Hardware checks
    gpu["hwmodel"] == "GH100"
    gpu["x-nvidia-gpu-arch-check"] == true
    gpu["dbgstat"] == "disabled"
    gpu["secboot"] == true
    gpu["measres"] == "success"
    gpu["x-nvidia-gpu-driver-rim-signature-verified"] == true
    gpu["x-nvidia-gpu-vbios-rim-signature-verified"] == true
    gpu["x-nvidia-overall-att-result"] == true

    # Confirming that GPU was attested by NVIDIA NRAS Service
    gpu["iss"] == "https://nras.attestation.nvidia.com"

    #
    # CPU
    #

    # Passing attestation policy
    input["submods"]["cpu0"]["ear.status"] == "affirming"
    cpu := input["submods"]["cpu0"]["ear.veraison.annotated-evidence"]["az-snp-vtpm"]

    # Security: Ensure the VM was not launched in debug mode (prevents memory scraping)
    cpu["policy_debug_allowed"] == "false"

    # Security: Ensure SMT (Hyperthreading) is disabled (mitigates side-channel attacks)
    cpu["platform_smt_enabled"] == "false"
}