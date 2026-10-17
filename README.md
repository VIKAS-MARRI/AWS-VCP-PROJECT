# AWS VPC Peering — EWB Cloud Labs, Project 01

**Student:** Vikas Marri  
**Region:** ap-south-1 (Mumbai)  
**Account:** *(see evidence/00-identity.txt)*  
**GitHub:** https://github.com/VIKAS-MARRI/AWS-VCP-PROJECT

---

## Project Overview

End-to-end AWS VPC Peering lab that demonstrates private cross-VPC communication
without an Internet Gateway on the target VPC.

### Address Plan

| Resource | CIDR / IP |
|---|---|
| ewb-vpc-a | 10.10.0.0/16 |
| ewb-a-public subnet | 10.10.1.0/24 |
| ewb-a-private subnet | 10.10.2.0/24 |
| ewb-vpc-b | 10.20.0.0/16 |
| ewb-b-private subnet | 10.20.1.0/24 |
| ewb-bastion | 10.10.1.10 + public IPv4 |
| ewb-app-a | 10.10.2.10 (no public IP) |
| ewb-app-b | 10.20.1.10 (no public IP) |

### Architecture

```
Internet
   |
   | (IGW: ewb-igw-a)
   |
[VPC A: 10.10.0.0/16]
  ├── ewb-a-public  10.10.1.0/24
  │      └── ewb-bastion  10.10.1.10  ← SSH entry point (public IP)
  └── ewb-a-private 10.10.2.0/24
         └── ewb-app-a    10.10.2.10  ← no public IP
                  |
                  |  VPC Peering (ewb-a-b-peer)
                  |
[VPC B: 10.20.0.0/16]   (NO IGW)
  └── ewb-b-private 10.20.1.0/24
         └── ewb-app-b   10.20.1.10  ← no public IP, reachable only via peer
```

---

## Stages

| # | Stage | Evidence |
|---|---|---|
| 0 | Setup & repo init | evidence/00-identity.txt |
| 1 | VPC A (subnets, IGW, route tables) | evidence/01-vpc-a.txt |
| 2 | VPC B + security groups | evidence/02-vpc-b-sgs.txt |
| 3 | Compute (key pair + 3 EC2 instances) | evidence/03-compute.txt |
| 4 | SSH baseline + pre-peering failure | evidence/04-ssh-test01.txt |
| 5 | VPC Peering (create + accept) | evidence/05-peering.txt |
| 6 | Routes (3 route table entries) | evidence/06-routes.txt |
| 7 | Verification (Tests 02-05 + controlled failure) | evidence/07-*.txt |
| 8 | Final report | report/Vikas_EWB_VPC_Peering.md |
| 9 | Cleanup | evidence/09-cleanup.txt |

---

## How to Run

```powershell
# Verify tools
.\vpc-peering-lab.ps1 -Stage 0

# Run a specific stage (e.g., build VPC A)
.\vpc-peering-lab.ps1 -Stage 1

# Cleanup (only after all evidence is saved)
.\vpc-peering-lab.ps1 -Cleanup
```

---

## Security Notes

- **No secrets in this repo.** Keys, credentials, and runtime state are git-ignored.
- SSH key stored at `~/.ssh/ewb-lab.pem` with owner-read-only ACL.
- Bastion SG allows SSH only from your current public IPv4 /32.
- No 0.0.0.0/0 on SSH or ICMP rules.

---

## Deliverables

- `vpc-peering-lab.ps1` — idempotent PowerShell automation
- `evidence/` — real CLI output from each stage
- `report/Vikas_EWB_VPC_Peering.md` — full submission report (Stage 8)
