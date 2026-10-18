# Project Handoff Report: AWS VPC Peering (Project 01)

**Generated:** 2026-10-18  
**Project:** EWB Cloud Labs – AWS VPC Peering (Project 01)  
**Status:** In Progress (Stages 0–3 Complete, Stage 4 Partial, Stages 5–9 Pending)

---

## 1. Environment

| Property | Value |
|---|---|
| **AWS Account ID** | `328681353246` |
| **IAM User ARN** | `arn:aws:iam::328681353246:user/ewb-lab-user` |
| **AWS Region** | `ap-south-1` (Mumbai) |
| **Git User Name** | `VIKAS-MARRI` |
| **Git User Email** | `vikasmarri9@gmail.com` |
| **Repository URL** | `https://github.com/VIKAS-MARRI/AWS-VCP-PROJECT.git` |
| **Active Branch** | `main` |
| **Working Directory** | `C:\Users\vikas\EWB-VPC-Peering` |
| **Operating System** | Windows 11 (AMD64) |
| **Shell** | PowerShell 5.1 / PowerShell Core |

---

## 2. Stage Status Table

> **Evaluation Rule:** A stage is marked **DONE** only if both the AWS resources exist and the verified evidence file is present and committed.

| Stage # | Stage Name | Status | Commit Hash | Evidence File |
|---|---|:---:|:---:|---|
| **Stage 0** | Setup, tooling check, git init & identity verification | **DONE** | `4517703` | [`evidence/00-identity.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/00-identity.txt) |
| **Stage 1** | VPC A: VPC, 2 subnets, IGW, route tables & associations | **DONE** | `70aad75` | [`evidence/01-vpc-a.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/01-vpc-a.txt) |
| **Stage 2** | VPC B: VPC, subnet, route table, 3 security groups | **DONE** | `3582872` | [`evidence/02-vpc-b-sgs.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/02-vpc-b-sgs.txt) |
| **Stage 3** | Compute: Key pair `ewb-lab`, 3 x `t3.micro` EC2 instances | **DONE** | `0f409b6` | [`evidence/03-compute.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/03-compute.txt) |
| **Stage 4** | SSH baseline & pre-peering failure capture (Test 01) | **PARTIAL** | `ae94a30` | [`evidence/04-ssh-test01.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/04-ssh-test01.txt) |
| **Stage 5** | VPC Peering: Create, accept, verify Active state | **NOT STARTED** | — | Pending (`evidence/05-peering.txt`) |
| **Stage 6** | Routes: Add peering routes across 3 route tables | **NOT STARTED** | — | Pending (`evidence/06-routes.txt`) |
| **Stage 7** | Verification: Tests 02–05 & controlled failure/recovery | **NOT STARTED** | — | Pending (`evidence/07-*.txt`) |
| **Stage 8** | Final submission report (`report/Vikas_EWB_VPC_Peering.md`) | **NOT STARTED** | — | Pending |
| **Stage 9** | Cleanup of lab resources | **NOT STARTED** | — | Pending (`evidence/09-cleanup.txt`) |

---

## 3. Live AWS Inventory

All resources listed below exist in region **`ap-south-1`** and are tagged `Project=EWB-VPC-Peering` and `Student=Vikas`.

### Inventory Table

| Resource Type | Resource Name | Resource ID | Key Attributes / CIDRs / State | Billable? |
|---|---|---|---|:---:|
| **VPC** | `ewb-vpc-a` | `vpc-085f611ada428a582` | `10.10.0.0/16`, DNS Hostnames Enabled | No |
| **VPC** | `ewb-vpc-b` | `vpc-033d9930b925f06bb` | `10.20.0.0/16`, No IGW attached | No |
| **Subnet** | `ewb-a-public` | `subnet-0504284fed260ff85` | `10.10.1.0/24`, AZ `ap-south-1a`, in VPC A | No |
| **Subnet** | `ewb-a-private` | `subnet-0dfebabb36e85e00e` | `10.10.2.0/24`, AZ `ap-south-1a`, in VPC A | No |
| **Subnet** | `ewb-b-private` | `subnet-00c65935f6ecc6754` | `10.20.1.0/24`, AZ `ap-south-1a`, in VPC B | No |
| **Internet Gateway** | `ewb-igw-a` | `igw-0aa7c7acb8d8bdd45` | Attached to `ewb-vpc-a` | No |
| **Route Table** | `ewb-rt-a-public` | `rtb-0c607525197a715e2` | Associated to `ewb-a-public`; default route `0.0.0.0/0 -> igw-0aa7c7acb8d8bdd45` | No |
| **Route Table** | `ewb-rt-a-private` | `rtb-0e390bcf60f3feabc` | Associated to `ewb-a-private`; local route only | No |
| **Route Table** | `ewb-rt-b-private` | `rtb-0fd554d97e9da9953` | Associated to `ewb-b-private`; local route only | No |
| **Security Group** | `ewb-sg-bastion` | `sg-021017caf97fe4251` | VPC A; Ingress: TCP 22 from operator IP | No |
| **Security Group** | `ewb-sg-app-a` | `sg-0d1a7fa830b423a7d` | VPC A; Ingress: TCP 22 from `10.10.1.10/32`, ICMP Echo from `10.20.1.10/32` | No |
| **Security Group** | `ewb-sg-app-b` | `sg-064ca4b1db6dcf9e3` | VPC B; Ingress: TCP 22 from `10.10.1.10/32`, ICMP Echo from `10.10.2.10/32` | No |
| **Key Pair** | `ewb-lab` | `key-0a80a06ea7407b2ff` | RSA key pair; private key stored at `~/.ssh/ewb-lab.pem` | No |
| **EC2 Instance** | `ewb-bastion` | `i-08970c0dc4cb29c2b` | `t3.micro`, **RUNNING**, Private: `10.10.1.10`, Public: `15.206.67.80` | **YES** |
| **EC2 Instance** | `ewb-app-a` | `i-0ed91a5a28d3d248c` | `t3.micro`, **RUNNING**, Private: `10.10.2.10`, Public: None | **YES** |
| **EC2 Instance** | `ewb-app-b` | `i-0077ff1eb903804b4` | `t3.micro`, **RUNNING**, Private: `10.20.1.10`, Public: None | **YES** |
| **EBS Volume** | (Bastion root) | `vol-08e3a37919666eace` | 8 GiB gp3, attached to `i-08970c0dc4cb29c2b` (`/dev/xvda`), `in-use` | **YES** |
| **EBS Volume** | (App-A root) | `vol-00bb522113ef9f9ee` | 8 GiB gp3, attached to `i-0ed91a5a28d3d248c` (`/dev/xvda`), `in-use` | **YES** |
| **EBS Volume** | (App-B root) | `vol-09122359978d1ee6f` | 8 GiB gp3, attached to `i-0077ff1eb903804b4` (`/dev/xvda`), `in-use` | **YES** |
| **Public IPv4** | (Bastion auto-assigned) | `15.206.67.80` | Associated to `eni-0c159807fa7aee1fc` on `ewb-bastion` | **YES** |
| **Elastic IP** | None | — | 0 allocated | No |
| **VPC Peering Connection**| None | — | 0 created (Stage 5 pending) | No |

### Billable Cost Summary

- **Running EC2 Instances (3):** 3 x `t3.micro` instances are currently in **`running`** state (~$0.0104/hr each in ap-south-1, unless covered under AWS Free Tier).
- **Attached EBS Storage (3):** 3 x 8 GiB gp3 volumes = 24 GiB total storage ($0.08/GB-month in ap-south-1).
- **Public IPv4 Address (1):** 1 in-use public IPv4 address on `ewb-bastion` ($0.005/hr).

---

## 4. Gaps and Mismatches

1. **Client Public IP Shift (Security Group Mismatch):**
   - In `lab-state.json`, `MyPublicIp` is recorded as `157.50.136.18`.
   - Security Group `ewb-sg-bastion` currently authorizes `157.50.136.170/32`, `157.50.136.0/24`, and IPv6 `2409:40f0:605d:f93e:8510:d5fe:987e:773b/128`.
   - The operator's live public IP has rotated to **`157.50.128.14`**.
   - As a result, incoming SSH connections to `ewb-bastion` (`15.206.67.80:22`) time out until the security group rule is authorized for `157.50.128.14/32`.

2. **Stage 4 Execution Failure (Exact Error):**
   - Command run:
     ```powershell
     $bastionHostname = ssh -o ConnectTimeout=15 ewb-bastion 'hostname'
     ```
   - Exact error captured:
     ```text
     ssh: connect to host 15.206.67.80 port 22: Connection timed out
     At line:18 char:12
     +     $out = ssh -o ConnectTimeout=20 -o BatchMode=yes ewb-bastion 'ech ...
     +            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
         + CategoryInfo          : NotSpecified: (ssh: connect to...ction timed out:String) [], RemoteException
         + FullyQualifiedErrorId : NativeCommandError
     ```
   - Consequently, SSH to `ewb-bastion`, SSH ProxyJump to `ewb-app-a`, and Test 01 ping (`ping 10.20.1.10` from `ewb-app-a`) were halted and not completed.

3. **Remote Git Tracking Branch Divergence:**
   - Local branch `main` tracks `origin/master`, which has an initial placeholder commit (`5c5c6f2`).
   - The remote repository also has branch `origin/main` pointing to commit `0f409b6`.
   - All work must be pushed to `origin main`.

4. **Uncommitted Files:**
   - None. `evidence/04-ssh-test01.txt` has been committed in commit `ae94a30`.

5. **AWS Resources vs Git Code:**
   - AWS resources exist up through Stage 3.
   - Private key `~/.ssh/ewb-lab.pem` and runtime state `lab-state.json` exist locally on the machine and are properly ignored by `.gitignore`.

---

## 5. Exact Next Steps

### Immediate Next Command to Run

The next agent must authorize the operator's current public IP in `ewb-sg-bastion` before attempting SSH or proceeding with Stage 4:

```powershell
# 1. Fetch current public IP and update Bastion Security Group (sg-021017caf97fe4251)
$currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
Write-Host "Current Public IP: $currentIp"
aws ec2 authorize-security-group-ingress `
    --group-id sg-021017caf97fe4251 `
    --protocol tcp `
    --port 22 `
    --cidr "$currentIp/32" `
    --region ap-south-1

# 2. Run Stage 4 to complete baseline SSH and capture Test 01 pre-peering failure
.\vpc-peering-lab.ps1 -Stage 4
```

### Remaining Stages in Order

1. **Stage 4: SSH Baseline & Pre-Peering Failure (Test 01)**
   - Run: `.\vpc-peering-lab.ps1 -Stage 4`
   - Verifies SSH to `ewb-bastion`, verifies ProxyJump to `ewb-app-a`.
   - Executes Test 01: ping from App-A (`10.10.2.10`) to App-B (`10.20.1.10`) and captures expected failure (packet loss / unreachable).
   - Commit: `stage 4: SSH baseline + pre-peering failure (Test 01) [evidence: evidence/04-ssh-test01.txt]`

2. **Stage 5: VPC Peering Connection**
   - Run: `.\vpc-peering-lab.ps1 -Stage 5`
   - Creates peering connection `ewb-a-b-peer` from VPC A (`vpc-085f611ada428a582`) to VPC B (`vpc-033d9930b925f06bb`).
   - Accepts peering connection and waits for `active` status.
   - Saves evidence to `evidence/05-peering.txt`.
   - Commit: `stage 5: VPC peering connection created and active [evidence: evidence/05-peering.txt]`

3. **Stage 6: Peering Routes**
   - Run: `.\vpc-peering-lab.ps1 -Stage 6`
   - Adds route `10.20.0.0/16 -> pcx-...` in private RT A (`rtb-0e390bcf60f3feabc`).
   - Adds route `10.10.0.0/16 -> pcx-...` in private RT B (`rtb-0fd554d97e9da9953`).
   - Adds route `10.20.0.0/16 -> pcx-...` in public RT A (`rtb-0c607525197a715e2`) for Bastion ProxyJump connectivity.
   - Saves evidence to `evidence/06-routes.txt`.
   - Commit: `stage 6: peering routes added to 3 route tables [evidence: evidence/06-routes.txt]`

4. **Stage 7: Verification Tests & Controlled Failure**
   - Run: `.\vpc-peering-lab.ps1 -Stage 7`
   - Test 02: Forward ping App-A -> App-B (0% packet loss).
   - Test 03: Reverse ping App-B -> App-A (0% packet loss).
   - Test 04: ProxyJump SSH to App-B hostname and IP.
   - Test 05: Verify App-A and App-B have no public IP assigned.
   - Controlled Failure: Revokes ICMP ingress rule on App-B SG, confirms ping fails, re-authorizes rule, confirms ping recovers.
   - Saves evidence to `evidence/07-*.txt`.
   - Commit: `stage 7: verification tests 02-05 and controlled failure [evidence: evidence/07-*.txt]`

5. **Stage 8: Final Submission Report**
   - Run: `.\vpc-peering-lab.ps1 -Stage 8`
   - Generates comprehensive markdown report at `report/Vikas_EWB_VPC_Peering.md`.
   - Commit: `stage 8: final submission report [report: report/Vikas_EWB_VPC_Peering.md]`

6. **Stage 9: Cleanup (Safety Critical)**
   - **DO NOT execute automatically.** Ask the user for explicit confirmation before running.
   - Run: `.\vpc-peering-lab.ps1 -Cleanup`
   - Terminates all 3 EC2 instances, waits for termination, deletes key pair, SGs, routes, peering connection, subnets, IGW, and VPCs tagged `Project=EWB-VPC-Peering`.
   - Commit: `stage 9: full lab cleanup [evidence: evidence/09-cleanup.txt]`

---

## 6. Known Gotchas and Decisions Made

1. **Fixed Private IPs:**
   - Bastion: `10.10.1.10`
   - App-A: `10.10.2.10`
   - App-B: `10.20.1.10`
   - Assigned statically at instance launch to guarantee deterministic routing and security group rules (`/32` CIDRs).

2. **Why the Public Route Table Requires the Peering Route:**
   - Bastion is located in subnet `ewb-a-public` (`10.10.1.0/24`) attached to route table `ewb-rt-a-public`.
   - When using SSH ProxyJump (`ssh ewb-app-b`), the client proxies through the Bastion daemon. Bastion initiates an outbound TCP 22 connection from `10.10.1.10` to App-B (`10.20.1.10`).
   - If `ewb-rt-a-public` does not contain a route for `10.20.0.0/16 -> pcx-...`, packets destined for `10.20.1.10` default to the IGW (`0.0.0.0/0`) where private IP packets are dropped. Hence, `ewb-rt-a-public` **must** include the peering route.

3. **Operator Dynamic Public IP Changes:**
   - The security group `ewb-sg-bastion` restricts inbound SSH (TCP 22) exclusively to the operator's public IP.
   - Home and mobile broadband networks frequently reassign dynamic IP addresses.
   - If the operator's IP changes, SSH times out. Always verify and authorize the latest IP from `https://checkip.amazonaws.com`.

4. **Bastion Public IP Ephemerality:**
   - `ewb-bastion` uses an auto-assigned public IPv4 address (`15.206.67.80`).
   - If `ewb-bastion` is stopped and restarted, AWS releases the IP and assigns a new one.
   - If restarted, update `BastionPublicIp` in `lab-state.json` and `~/.ssh/config`.

5. **Amazon Linux 2023 Dynamic AMI Resolution:**
   - Rather than hardcoding AMI IDs that change per region/release, `vpc-peering-lab.ps1` resolves the latest standard Amazon Linux 2023 AMI via SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` (`ami-04394a3a96907e9ec`).

6. **Windows OpenSSH Key Permissions:**
   - OpenSSH for Windows rejects private keys with permissive permissions. The automation uses `icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:R"` to lock `ewb-lab.pem` to owner read-only.

---

## 7. Safety Rules to Maintain

1. **Zero Secret Policy:**
   - Never commit `*.pem`, `*.key`, credentials files, or `lab-state.json`.
   - Ensure `.gitignore` remains intact.
2. **Strict CIDR Security:**
   - Never use `0.0.0.0/0` on inbound SSH (port 22) or ICMP echo rules.
   - Bastion SSH ingress must remain limited to the operator's `/32`.
   - App-A and App-B ingress rules must strictly match individual `/32` IPs.
3. **Preserve Default Infrastructure:**
   - Never delete or modify the default VPC or any non-lab resources.
4. **Scope-Limited Cleanup:**
   - All cleanup and deletion actions must strictly filter on `Project=EWB-VPC-Peering` and `Student=Vikas`.
5. **Mandatory User Confirmations:**
   - **Stage 3 Check:** Ask user before launching compute instances (if not already running).
   - **Stage 9 Check:** Always prompt and receive explicit approval from the user before executing `.\vpc-peering-lab.ps1 -Cleanup`.
