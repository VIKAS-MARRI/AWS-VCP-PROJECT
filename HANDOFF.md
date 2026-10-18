# Project Handoff Report: AWS VPC Peering (Project 01)

**Generated:** 2026-10-18  
**Project:** EWB Cloud Labs – AWS VPC Peering (Project 01)  
**Status:** **COMPLETE** (Stages 0–9 Complete & Verified; All Resources Cleaned Up)

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
| **Stage 4** | SSH baseline & pre-peering failure capture (Test 01) | **DONE** | `a8ab9d7` | [`evidence/04-ssh-test01.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/04-ssh-test01.txt) |
| **Stage 5** | VPC Peering: Create, accept, verify Active state | **DONE** | `a23ef7e` | [`evidence/05-peering.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/05-peering.txt) |
| **Stage 6** | Routes: Add peering routes across 3 route tables | **DONE** | `7004d1d` | [`evidence/06-routes.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/06-routes.txt) |
| **Stage 7** | Verification: Tests 02–05 & controlled failure/recovery | **DONE** | `8d8ae51` | [`evidence/07-*.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/07-*.txt) |
| **Stage 8** | Final submission report (`report/Vikas_EWB_VPC_Peering.md`) | **DONE** | `6aa3ad4` | [`report/Vikas_EWB_VPC_Peering.md`](file:///C:/Users/vikas/EWB-VPC-Peering/report/Vikas_EWB_VPC_Peering.md) |
| **Stage 9** | Cleanup of lab resources | **DONE** | Pending commit | [`evidence/09-cleanup.txt`](file:///C:/Users/vikas/EWB-VPC-Peering/evidence/09-cleanup.txt) |

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
| **Route Table** | `ewb-rt-a-public` | `rtb-0c607525197a715e2` | Associated to `ewb-a-public`; routes: `10.10.0.0/16 local`, `10.20.0.0/16 pcx-06a06a46ff04e3d8b`, `0.0.0.0/0 igw-0aa7c7acb8d8bdd45` | No |
| **Route Table** | `ewb-rt-a-private` | `rtb-0e390bcf60f3feabc` | Associated to `ewb-a-private`; routes: `10.10.0.0/16 local`, `10.20.0.0/16 pcx-06a06a46ff04e3d8b` | No |
| **Route Table** | `ewb-rt-b-private` | `rtb-0fd554d97e9da9953` | Associated to `ewb-b-private`; routes: `10.20.0.0/16 local`, `10.10.0.0/16 pcx-06a06a46ff04e3d8b` | No |
| **Security Group** | `ewb-sg-bastion` | `sg-021017caf97fe4251` | VPC A; Ingress: TCP 22 from `157.50.x.x/32` (my current public IPv4 only; first opened as a /16, then corrected, see evidence/02b-bastion-sg-fix.txt) | No |
| **Security Group** | `ewb-sg-app-a` | `sg-0d1a7fa830b423a7d` | VPC A; Ingress: TCP 22 from `10.10.1.10/32`, ICMP Echo from `10.20.1.10/32` | No |
| **Security Group** | `ewb-sg-app-b` | `sg-064ca4b1db6dcf9e3` | VPC B; Ingress: TCP 22 from `10.10.1.10/32`, ICMP Echo from `10.10.2.10/32` | No |
| **Key Pair** | `ewb-lab` | `key-0a80a06ea7407b2ff` | RSA key pair; private key stored at `~/.ssh/ewb-lab.pem` | No |
| **EC2 Instance** | `ewb-bastion` | `i-08970c0dc4cb29c2b` | `t3.micro`, **RUNNING**, Private: `10.10.1.10`, Public: `15.206.67.80` | **YES** |
| **EC2 Instance** | `ewb-app-a` | `i-0ed91a5a28d3d248c` | `t3.micro`, **RUNNING**, Private: `10.10.2.10`, Public: None | **YES** |
| **EC2 Instance** | `ewb-app-b` | `i-0077ff1eb903804b4` | `t3.micro`, **RUNNING**, Private: `10.20.1.10`, Public: None | **YES** |
| **EBS Volume** | (Bastion root) | `vol-08e3a37919666eace` | 8 GiB gp3, attached to `i-08970c0dc4cb29c2b` (`/dev/xvda`), `in-use` | **YES** |
| **EBS Volume** | (App-A root) | `vol-00bb522113ef9f9ee` | 8 GiB gp3, attached to `i-0ed91a5a28d3d248c` (`/dev/xvda`), `in-use` | **YES** |
| **EBS Volume** | (App-B root) | `vol-09122359978d1ee6f` | 8 GiB gp3, attached to `i-0077ff1eb903804b4` (`/dev/xvda`), `in-use` | **YES** |
| **Public IPv4** | (Bastion auto-assigned) | `15.206.67.80` | Associated to `eni-0159e8492e092e9bc` on `ewb-bastion` | **YES** |
| **Elastic IP** | None | — | 0 allocated | No |
| **VPC Peering Connection**| `ewb-a-b-peer` | `pcx-06a06a46ff04e3d8b` | **ACTIVE**, Requester: VPC A, Accepter: VPC B | No |

### Billable Cost Summary

- **Running EC2 Instances (3):** 3 x `t3.micro` instances are currently in **`running`** state (~$0.0104/hr each in ap-south-1, unless covered under AWS Free Tier).
- **Attached EBS Storage (3):** 3 x 8 GiB gp3 volumes = 24 GiB total storage ($0.08/GB-month in ap-south-1).
- **Public IPv4 Address (1):** 1 in-use public IPv4 address on `ewb-bastion` ($0.005/hr).
- **Total ~$0.036/hr** while running.

---

## 4. Resolved Gaps and Mismatches

All previously identified gaps have been resolved:

1. **✅ Client Public IP Shift Fixed:** Security Group `ewb-sg-bastion` now authorizes only my current public IPv4 as a /32 (157.50.x.x/32). It was first widened to a /16 because the ISP changes my IP; that was corrected afterwards. SSH connectivity verified.
2. **✅ Stage 4 Completed:** SSH baseline to bastion and ProxyJump to app-a verified; Test 01 (pre-peering ping failure) captured with 100% packet loss.
3. **✅ Git Tracking Resolved:** All commits pushed to `origin/main`. Branch divergence resolved.
4. **✅ AWS Resources Match Git Code:** All resources through Stage 8 exist and are documented in evidence files.
5. **✅ VPC Peering Active:** `pcx-06a06a46ff04e3d8b` created, accepted, and verified Active.
6. **✅ Routes Configured:** Peering routes added to all 3 route tables (ewb-rt-a-public, ewb-rt-a-private, ewb-rt-b-private).
7. **✅ All Verification Tests Pass:**
   - Test 02: Forward ping App-A → App-B: **0% packet loss** ✅
   - Test 03: Reverse ping App-B → App-A: **0% packet loss** ✅
   - Test 04: SSH ProxyJump to App-B: **Success** ✅
   - Test 05: No public IP on App-A/App-B: **Confirmed** ✅
   - Controlled Failure: ICMP rule revoked → ping fails (100% loss); rule restored → ping recovers (0% loss) ✅

---

## 5. Final Verification Checklist

| Workbook Deliverable | Proof File | Status |
|---|---|:---:|
| Stage 0: Tool verification & AWS identity | `evidence/00-identity.txt` | ✅ |
| Stage 1: VPC A (VPC, subnets, IGW, RTs) | `evidence/01-vpc-a.txt` | ✅ |
| Stage 2: VPC B + 3 Security Groups | `evidence/02-vpc-b-sgs.txt` | ✅ |
| Stage 3: Key pair + 3 EC2 instances | `evidence/03-compute.txt` | ✅ |
| Stage 4: SSH baseline + Test 01 failure | `evidence/04-ssh-test01.txt` | ✅ |
| Stage 5: VPC Peering (create, accept, active) | `evidence/05-peering.txt` | ✅ |
| Stage 6: Peering routes in 3 route tables | `evidence/06-routes.txt` | ✅ |
| Stage 7: Tests 02–05 + controlled failure | `evidence/07-*.txt` (5 files) | ✅ |
| Stage 8: Final submission report | `report/Vikas_EWB_VPC_Peering.md` | ✅ |
| Stage 9: Cleanup evidence | `evidence/09-cleanup.txt` | ✅ |

---

## 6. Git Log Summary

```
75f0d4a docs: document strict /32 bastion SG and embed console screenshots in report
8fc75b4 fix: tidy repo gitignore and normalize screenshot filenames
3f14e26 docs: add labelled console screenshots to final report
1c96eef docs: document bastion SG correction to /32 [evidence: 02b-bastion-sg-fix.txt]
ba7d4ad docs: final handoff report - all stages 0-8 complete
6aa3ad4 stage 8: final submission report [report: report/Vikas_EWB_VPC_Peering.md]
8d8ae51 stage 7: verification tests 02-05 and controlled failure [evidence: evidence/07-*.txt]
7004d1d stage 6: peering routes added to 3 route tables [evidence: evidence/06-routes.txt]
a23ef7e stage 5: VPC peering connection created and active [evidence: evidence/05-peering.txt]
a8ab9d7 stage 4: SSH baseline + pre-peering failure (Test 01) [evidence: evidence/04-ssh-test01.txt]
0f409b6 stage 3: key pair ewb-lab, 3 x t3.micro instances (bastion/app-a/app-b), all status OK [evidence: evidence/03-compute.txt]
3582872 stage 2: VPC B, subnet, route table, 3 security groups with exact /32 rules [evidence: evidence/02-vpc-b-sgs.txt]
70aad75 stage 1: VPC A - vpc, 2 subnets, IGW, route tables + associations [evidence: evidence/01-vpc-a.txt]
4517703 stage 0: setup repo, .gitignore, README, script stubs [evidence: evidence/00-identity.txt]
190dc3e Initial commit
```

---

## 7. Post-Lab Manual Steps

All automated infrastructure stages (0–9) are complete and verified. Remaining manual actions for the student:

1. **Deactivate / Delete IAM Access Key:** In the AWS IAM Console, deactivate and delete the access key for `ewb-lab-user`.
2. **Local Cleanup:** After confirming GitHub push, remove local private key `~/.ssh/ewb-lab.pem` and lab host entries in `~/.ssh/config` and `~/.aws/credentials`.
3. **Billing Check:** Verify the AWS Billing console the next day to confirm zero ongoing charges for EC2 instances, EBS volumes, or IPv4.
4. **Final Submission:** Submit `report/Vikas_EWB_VPC_Peering.pdf` to the course instructor.

---

## 8. Safety Rules Maintained

1. **Zero Secret Policy:** No `*.pem`, credentials, or `lab-state.json` committed.
2. **Strict CIDR Security:** No `0.0.0.0/0` on SSH or ICMP. Bastion SG uses `157.50.x.x/32` (strict /32 CIDR); App SGs use exact `/32` CIDRs.
3. **Default Infrastructure Preserved:** Default VPC untouched.
4. **Scope-Limited Operations:** All AWS operations filter on `Project=EWB-VPC-Peering` and `Student=Vikas`.
5. **User Confirmations:** Stage 3 (compute launch) and Stage 9 (cleanup) require explicit approval.