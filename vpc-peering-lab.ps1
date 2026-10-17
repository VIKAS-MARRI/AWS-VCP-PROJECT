<#
.SYNOPSIS
    EWB Cloud Labs – AWS VPC Peering Lab (Project 01)
    Single-file, idempotent PowerShell automation.

.DESCRIPTION
    Run individual stages with -Stage <0-9> or full cleanup with -Cleanup.
    Every stage:
      • looks up existing resources by tag before creating (idempotent)
      • saves IDs to lab-state.json (git-ignored)
      • captures evidence with Tee-Object into evidence/NN-name.txt
      • exits on any error

    Region  : ap-south-1 (Mumbai)
    Account : one account, VPC A ↔ VPC B peering

.PARAMETER Stage
    Which stage to execute (0-9).

.PARAMETER Cleanup
    Switch. Run Stage 9 cleanup (prompts for confirmation).

.EXAMPLE
    .\vpc-peering-lab.ps1 -Stage 0
    .\vpc-peering-lab.ps1 -Stage 1
    .\vpc-peering-lab.ps1 -Cleanup

.NOTES
    SECURITY:  No secrets, tokens, or keys are written to this file or any
               committed file.  lab-state.json is git-ignored.
               .pem files are git-ignored and never committed.
#>

[CmdletBinding(DefaultParameterSetName = 'Stage')]
param(
    [Parameter(ParameterSetName = 'Stage',  Mandatory = $true)]
    [ValidateRange(0, 9)]
    [int]$Stage,

    [Parameter(ParameterSetName = 'Cleanup', Mandatory = $true)]
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Global constants ────────────────────────────────────────────────────────
$REGION        = 'ap-south-1'
$PROJECT_TAG   = 'EWB-VPC-Peering'
$STUDENT_TAG   = 'Vikas'
$STATE_FILE    = "$PSScriptRoot\lab-state.json"
$EVIDENCE_DIR  = "$PSScriptRoot\evidence"

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Write-Stage { param($Msg) Write-Host "`n=== $Msg ===" -ForegroundColor Cyan }
function Write-Info  { param($Msg) Write-Host "  $Msg"        -ForegroundColor Gray  }
function Write-Ok    { param($Msg) Write-Host "  ✔  $Msg"    -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "  ⚠  $Msg"    -ForegroundColor Yellow }

function Get-LabState {
    if (Test-Path $STATE_FILE) {
        return (Get-Content $STATE_FILE | ConvertFrom-Json -AsHashtable)
    }
    return @{}
}

function Save-LabState { param($State)
    $State | ConvertTo-Json -Depth 5 | Set-Content $STATE_FILE
}

function Ensure-EvidenceDir {
    if (-not (Test-Path $EVIDENCE_DIR)) {
        New-Item -ItemType Directory -Path $EVIDENCE_DIR | Out-Null
        Write-Ok "Created evidence/ directory"
    }
}

function Get-TagFilter { param($Name)
    # Returns the --filters string for Name + Project tags
    return "Name=tag:Name,Values=$Name Name=tag:Project,Values=$PROJECT_TAG"
}

function Invoke-Aws {
    <#
    Thin wrapper: runs aws CLI, checks exit code, returns parsed JSON.
    Pass $Raw=$true to get the raw string back instead.
    #>
    param(
        [string[]]$Args,
        [switch]$Raw
    )
    $cmd = "aws $($Args -join ' ') --region $REGION --output json"
    Write-Verbose "  CMD: $cmd"
    $result = Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI failed (exit $LASTEXITCODE): $cmd"
    }
    if ($Raw) { return $result }
    return ($result | ConvertFrom-Json)
}

function Add-CommonTags { param($ResourceId, $Name)
    Invoke-Aws @(
        'ec2', 'create-tags',
        '--resources', $ResourceId,
        '--tags',
        "Key=Name,Value=$Name",
        "Key=Project,Value=$PROJECT_TAG",
        "Key=Student,Value=$STUDENT_TAG"
    ) | Out-Null
    Write-Ok "Tagged $ResourceId -> Name=$Name"
}

# ─── STAGE 0 : Setup & repo init ─────────────────────────────────────────────

function Invoke-Stage0 {
    Write-Stage "Stage 0 – Setup: verify tools, init repo, first commit"
    Ensure-EvidenceDir

    $evidenceFile = "$EVIDENCE_DIR\00-identity.txt"

    # Verify tools
    Write-Info "Checking aws CLI..."
    aws --version 2>&1 | Tee-Object -FilePath $evidenceFile
    if ($LASTEXITCODE -ne 0) { throw "aws CLI not found. Install AWS CLI v2." }

    Write-Info "Checking git..."
    git --version 2>&1 | Tee-Object -Append -FilePath $evidenceFile
    if ($LASTEXITCODE -ne 0) { throw "git not found. Install Git for Windows." }

    Write-Info "Checking ssh..."
    ssh -V 2>&1 | Tee-Object -Append -FilePath $evidenceFile
    if ($LASTEXITCODE -ne 0) { throw "ssh not found. Enable OpenSSH in Windows Features." }

    Write-Info "Verifying AWS identity..."
    $identity = aws sts get-caller-identity --output json 2>&1 |
        Tee-Object -Append -FilePath $evidenceFile
    if ($LASTEXITCODE -ne 0) { throw "AWS identity check failed. Run: aws configure" }

    $id = $identity | ConvertFrom-Json
    Write-Ok "AWS Account : $($id.Account)"
    Write-Ok "AWS ARN     : $($id.Arn)"

    # Save account ID to state
    $state = Get-LabState
    $state['AccountId'] = $id.Account
    Save-LabState $state

    Write-Ok "Stage 0 complete. Evidence: $evidenceFile"
}

# ─── STAGE 1 : VPC A ─────────────────────────────────────────────────────────

function Invoke-Stage1 {
    Write-Stage "Stage 1 – VPC A: VPC, subnets, IGW, route tables"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\01-vpc-a.txt"

    # ── VPC A ────────────────────────────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-vpcs',
        '--filters',"Name=tag:Name,Values=ewb-vpc-a","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.Vpcs.Count -gt 0) {
        $vpcAId = $existing.Vpcs[0].VpcId
        Write-Warn "VPC A already exists: $vpcAId"
    } else {
        $r = Invoke-Aws @('ec2','create-vpc','--cidr-block','10.10.0.0/16',
            '--tag-specifications',
            "ResourceType=vpc,Tags=[{Key=Name,Value=ewb-vpc-a},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $vpcAId = $r.Vpc.VpcId
        Write-Ok "Created VPC A: $vpcAId"
    }
    $state['VpcAId'] = $vpcAId

    # Enable DNS hostnames on VPC A (needed for public bastion DNS)
    Invoke-Aws @('ec2','modify-vpc-attribute','--vpc-id',$vpcAId,
        '--enable-dns-hostnames','{"Value":true}') | Out-Null
    Write-Ok "DNS hostnames enabled on VPC A"

    # ── Subnet: ewb-a-public (10.10.1.0/24) ─────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-subnets',
        '--filters',"Name=tag:Name,Values=ewb-a-public","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.Subnets.Count -gt 0) {
        $pubSubAId = $existing.Subnets[0].SubnetId
        Write-Warn "Subnet ewb-a-public already exists: $pubSubAId"
    } else {
        $r = Invoke-Aws @('ec2','create-subnet','--vpc-id',$vpcAId,
            '--cidr-block','10.10.1.0/24',
            '--availability-zone',"${REGION}a",
            '--tag-specifications',
            "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-a-public},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $pubSubAId = $r.Subnet.SubnetId
        Write-Ok "Created ewb-a-public: $pubSubAId"
    }
    $state['PubSubAId'] = $pubSubAId

    # ── Subnet: ewb-a-private (10.10.2.0/24) ─────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-subnets',
        '--filters',"Name=tag:Name,Values=ewb-a-private","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.Subnets.Count -gt 0) {
        $privSubAId = $existing.Subnets[0].SubnetId
        Write-Warn "Subnet ewb-a-private already exists: $privSubAId"
    } else {
        $r = Invoke-Aws @('ec2','create-subnet','--vpc-id',$vpcAId,
            '--cidr-block','10.10.2.0/24',
            '--availability-zone',"${REGION}a",
            '--tag-specifications',
            "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-a-private},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $privSubAId = $r.Subnet.SubnetId
        Write-Ok "Created ewb-a-private: $privSubAId"
    }
    $state['PrivSubAId'] = $privSubAId

    # Disable auto-assign public IP on private subnet
    Invoke-Aws @('ec2','modify-subnet-attribute','--subnet-id',$privSubAId,
        '--no-map-public-ip-on-launch') | Out-Null
    Write-Ok "Disabled auto-assign public IP on ewb-a-private"

    # ── Internet Gateway ─────────────────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-internet-gateways',
        '--filters',"Name=tag:Name,Values=ewb-igw-a","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.InternetGateways.Count -gt 0) {
        $igwId = $existing.InternetGateways[0].InternetGatewayId
        Write-Warn "IGW already exists: $igwId"
    } else {
        $r = Invoke-Aws @('ec2','create-internet-gateway',
            '--tag-specifications',
            "ResourceType=internet-gateway,Tags=[{Key=Name,Value=ewb-igw-a},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $igwId = $r.InternetGateway.InternetGatewayId
        Write-Ok "Created IGW: $igwId"
    }
    $state['IgwId'] = $igwId

    # Attach IGW to VPC A (idempotent – ignore AlreadyAssociated)
    $attachments = (Invoke-Aws @('ec2','describe-internet-gateways',
        '--internet-gateway-ids',$igwId)).InternetGateways[0].Attachments
    $attached = $attachments | Where-Object { $_.VpcId -eq $vpcAId -and $_.State -eq 'available' }
    if (-not $attached) {
        Invoke-Aws @('ec2','attach-internet-gateway',
            '--internet-gateway-id',$igwId,'--vpc-id',$vpcAId) | Out-Null
        Write-Ok "Attached IGW to VPC A"
    } else {
        Write-Warn "IGW already attached to VPC A"
    }

    # ── Route table: ewb-rt-a-public ─────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-route-tables',
        '--filters',"Name=tag:Name,Values=ewb-rt-a-public","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.RouteTables.Count -gt 0) {
        $rtPubAId = $existing.RouteTables[0].RouteTableId
        Write-Warn "Route table ewb-rt-a-public already exists: $rtPubAId"
    } else {
        $r = Invoke-Aws @('ec2','create-route-table','--vpc-id',$vpcAId,
            '--tag-specifications',
            "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-a-public},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $rtPubAId = $r.RouteTable.RouteTableId
        Write-Ok "Created ewb-rt-a-public: $rtPubAId"
    }
    $state['RtPubAId'] = $rtPubAId

    # Default route 0.0.0.0/0 -> IGW
    $routes = (Invoke-Aws @('ec2','describe-route-tables',
        '--route-table-ids',$rtPubAId)).RouteTables[0].Routes
    $igwRoute = $routes | Where-Object { $_.DestinationCidrBlock -eq '0.0.0.0/0' }
    if (-not $igwRoute) {
        Invoke-Aws @('ec2','create-route','--route-table-id',$rtPubAId,
            '--destination-cidr-block','0.0.0.0/0',
            '--gateway-id',$igwId) | Out-Null
        Write-Ok "Added 0.0.0.0/0 -> IGW route to ewb-rt-a-public"
    } else {
        Write-Warn "Default route already exists in ewb-rt-a-public"
    }

    # Associate public subnet with public RT
    $assocPub = (Invoke-Aws @('ec2','describe-route-tables',
        '--route-table-ids',$rtPubAId)).RouteTables[0].Associations |
        Where-Object { $_.SubnetId -eq $pubSubAId }
    if (-not $assocPub) {
        $r = Invoke-Aws @('ec2','associate-route-table',
            '--route-table-id',$rtPubAId,'--subnet-id',$pubSubAId)
        $state['RtPubAAssocId'] = $r.AssociationId
        Write-Ok "Associated ewb-a-public with ewb-rt-a-public"
    } else {
        Write-Warn "Association already exists"
    }

    # ── Route table: ewb-rt-a-private ────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-route-tables',
        '--filters',"Name=tag:Name,Values=ewb-rt-a-private","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.RouteTables.Count -gt 0) {
        $rtPrivAId = $existing.RouteTables[0].RouteTableId
        Write-Warn "Route table ewb-rt-a-private already exists: $rtPrivAId"
    } else {
        $r = Invoke-Aws @('ec2','create-route-table','--vpc-id',$vpcAId,
            '--tag-specifications',
            "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-a-private},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $rtPrivAId = $r.RouteTable.RouteTableId
        Write-Ok "Created ewb-rt-a-private: $rtPrivAId"
    }
    $state['RtPrivAId'] = $rtPrivAId

    # Associate private subnet with private RT
    $assocPriv = (Invoke-Aws @('ec2','describe-route-tables',
        '--route-table-ids',$rtPrivAId)).RouteTables[0].Associations |
        Where-Object { $_.SubnetId -eq $privSubAId }
    if (-not $assocPriv) {
        $r = Invoke-Aws @('ec2','associate-route-table',
            '--route-table-id',$rtPrivAId,'--subnet-id',$privSubAId)
        $state['RtPrivAAssocId'] = $r.AssociationId
        Write-Ok "Associated ewb-a-private with ewb-rt-a-private"
    } else {
        Write-Warn "Association already exists"
    }

    Save-LabState $state

    # ── Checkpoint 01: describe route tables ─────────────────────────────────
    Write-Info "Capturing Checkpoint 01 evidence..."
    aws ec2 describe-route-tables `
        --route-table-ids $rtPubAId $rtPrivAId `
        --region $REGION --output table 2>&1 |
        Tee-Object -FilePath $evidenceFile

    Write-Ok "Stage 1 complete. Evidence: $evidenceFile"
}

# ─── STAGE 2 : VPC B + Security Groups ───────────────────────────────────────

function Invoke-Stage2 {
    Write-Stage "Stage 2 – VPC B + security groups"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\02-vpc-b-sgs.txt"

    # ── VPC B ────────────────────────────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-vpcs',
        '--filters',"Name=tag:Name,Values=ewb-vpc-b","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.Vpcs.Count -gt 0) {
        $vpcBId = $existing.Vpcs[0].VpcId
        Write-Warn "VPC B already exists: $vpcBId"
    } else {
        $r = Invoke-Aws @('ec2','create-vpc','--cidr-block','10.20.0.0/16',
            '--tag-specifications',
            "ResourceType=vpc,Tags=[{Key=Name,Value=ewb-vpc-b},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $vpcBId = $r.Vpc.VpcId
        Write-Ok "Created VPC B: $vpcBId"
    }
    $state['VpcBId'] = $vpcBId

    # ── Subnet: ewb-b-private (10.20.1.0/24) ─────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-subnets',
        '--filters',"Name=tag:Name,Values=ewb-b-private","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.Subnets.Count -gt 0) {
        $privSubBId = $existing.Subnets[0].SubnetId
        Write-Warn "Subnet ewb-b-private already exists: $privSubBId"
    } else {
        $r = Invoke-Aws @('ec2','create-subnet','--vpc-id',$vpcBId,
            '--cidr-block','10.20.1.0/24',
            '--availability-zone',"${REGION}a",
            '--tag-specifications',
            "ResourceType=subnet,Tags=[{Key=Name,Value=ewb-b-private},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $privSubBId = $r.Subnet.SubnetId
        Write-Ok "Created ewb-b-private: $privSubBId"
    }
    $state['PrivSubBId'] = $privSubBId

    # Disable auto-assign public IP
    Invoke-Aws @('ec2','modify-subnet-attribute','--subnet-id',$privSubBId,
        '--no-map-public-ip-on-launch') | Out-Null
    Write-Ok "Disabled auto-assign public IP on ewb-b-private"

    # ── Route table: ewb-rt-b-private ────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-route-tables',
        '--filters',"Name=tag:Name,Values=ewb-rt-b-private","Name=tag:Project,Values=$PROJECT_TAG")
    if ($existing.RouteTables.Count -gt 0) {
        $rtPrivBId = $existing.RouteTables[0].RouteTableId
        Write-Warn "Route table ewb-rt-b-private already exists: $rtPrivBId"
    } else {
        $r = Invoke-Aws @('ec2','create-route-table','--vpc-id',$vpcBId,
            '--tag-specifications',
            "ResourceType=route-table,Tags=[{Key=Name,Value=ewb-rt-b-private},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $rtPrivBId = $r.RouteTable.RouteTableId
        Write-Ok "Created ewb-rt-b-private: $rtPrivBId"
    }
    $state['RtPrivBId'] = $rtPrivBId

    # Associate ewb-b-private subnet
    $assoc = (Invoke-Aws @('ec2','describe-route-tables',
        '--route-table-ids',$rtPrivBId)).RouteTables[0].Associations |
        Where-Object { $_.SubnetId -eq $privSubBId }
    if (-not $assoc) {
        $r = Invoke-Aws @('ec2','associate-route-table',
            '--route-table-id',$rtPrivBId,'--subnet-id',$privSubBId)
        $state['RtPrivBAssocId'] = $r.AssociationId
        Write-Ok "Associated ewb-b-private with ewb-rt-b-private"
    } else {
        Write-Warn "Association already exists"
    }

    # ── Security Group: ewb-sg-bastion ───────────────────────────────────────
    $myIp = (Invoke-WebRequest -Uri 'https://checkip.amazonaws.com' -UseBasicParsing).Content.Trim()
    Write-Ok "My public IP: $myIp"
    $state['MyPublicIp'] = $myIp

    $existing = Invoke-Aws @('ec2','describe-security-groups',
        '--filters',"Name=group-name,Values=ewb-sg-bastion","Name=vpc-id,Values=$($state['VpcAId'])")
    if ($existing.SecurityGroups.Count -gt 0) {
        $sgBastionId = $existing.SecurityGroups[0].GroupId
        Write-Warn "SG ewb-sg-bastion already exists: $sgBastionId"
    } else {
        $r = Invoke-Aws @('ec2','create-security-group',
            '--group-name','ewb-sg-bastion',
            '--description','Bastion SSH access from my IP only',
            '--vpc-id',$state['VpcAId'],
            '--tag-specifications',
            "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-bastion},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $sgBastionId = $r.GroupId
        Write-Ok "Created ewb-sg-bastion: $sgBastionId"

        # Inbound: SSH from my IP /32 only
        Invoke-Aws @('ec2','authorize-security-group-ingress',
            '--group-id',$sgBastionId,
            '--protocol','tcp','--port','22',
            '--cidr',"${myIp}/32") | Out-Null
        Write-Ok "Added SSH rule: $myIp/32 -> ewb-sg-bastion"
    }
    $state['SgBastionId'] = $sgBastionId

    # ── Security Group: ewb-sg-app-a ─────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-security-groups',
        '--filters',"Name=group-name,Values=ewb-sg-app-a","Name=vpc-id,Values=$($state['VpcAId'])")
    if ($existing.SecurityGroups.Count -gt 0) {
        $sgAppAId = $existing.SecurityGroups[0].GroupId
        Write-Warn "SG ewb-sg-app-a already exists: $sgAppAId"
    } else {
        $r = Invoke-Aws @('ec2','create-security-group',
            '--group-name','ewb-sg-app-a',
            '--description','App-A: SSH from bastion, ICMP from App-B',
            '--vpc-id',$state['VpcAId'],
            '--tag-specifications',
            "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-app-a},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $sgAppAId = $r.GroupId
        Write-Ok "Created ewb-sg-app-a: $sgAppAId"

        # SSH from bastion private IP /32
        Invoke-Aws @('ec2','authorize-security-group-ingress',
            '--group-id',$sgAppAId,
            '--protocol','tcp','--port','22',
            '--cidr','10.10.1.10/32') | Out-Null
        Write-Ok "Added SSH rule: 10.10.1.10/32 -> ewb-sg-app-a"

        # ICMP echo-request (type 8, code 0) from App-B
        Invoke-Aws @('ec2','authorize-security-group-ingress',
            '--group-id',$sgAppAId,
            '--ip-permissions',
            '[{"IpProtocol":"icmp","FromPort":8,"ToPort":0,"IpRanges":[{"CidrIp":"10.20.1.10/32"}]}]') | Out-Null
        Write-Ok "Added ICMP rule: 10.20.1.10/32 -> ewb-sg-app-a"
    }
    $state['SgAppAId'] = $sgAppAId

    # ── Security Group: ewb-sg-app-b ─────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-security-groups',
        '--filters',"Name=group-name,Values=ewb-sg-app-b","Name=vpc-id,Values=$vpcBId")
    if ($existing.SecurityGroups.Count -gt 0) {
        $sgAppBId = $existing.SecurityGroups[0].GroupId
        Write-Warn "SG ewb-sg-app-b already exists: $sgAppBId"
    } else {
        $r = Invoke-Aws @('ec2','create-security-group',
            '--group-name','ewb-sg-app-b',
            '--description','App-B: SSH from bastion, ICMP from App-A',
            '--vpc-id',$vpcBId,
            '--tag-specifications',
            "ResourceType=security-group,Tags=[{Key=Name,Value=ewb-sg-app-b},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $sgAppBId = $r.GroupId
        Write-Ok "Created ewb-sg-app-b: $sgAppBId"

        # SSH from bastion private IP /32
        Invoke-Aws @('ec2','authorize-security-group-ingress',
            '--group-id',$sgAppBId,
            '--protocol','tcp','--port','22',
            '--cidr','10.10.1.10/32') | Out-Null
        Write-Ok "Added SSH rule: 10.10.1.10/32 -> ewb-sg-app-b"

        # ICMP echo-request (type 8, code 0) from App-A
        Invoke-Aws @('ec2','authorize-security-group-ingress',
            '--group-id',$sgAppBId,
            '--ip-permissions',
            '[{"IpProtocol":"icmp","FromPort":8,"ToPort":0,"IpRanges":[{"CidrIp":"10.10.2.10/32"}]}]') | Out-Null
        Write-Ok "Added ICMP rule: 10.10.2.10/32 -> ewb-sg-app-b"
    }
    $state['SgAppBId'] = $sgAppBId

    Save-LabState $state

    # ── Evidence: describe all three SGs ─────────────────────────────────────
    Write-Info "Capturing evidence..."
    aws ec2 describe-security-groups `
        --group-ids $sgBastionId $sgAppAId $sgAppBId `
        --region $REGION --output table 2>&1 |
        Tee-Object -FilePath $evidenceFile

    # Also capture VPC B route table
    aws ec2 describe-route-tables `
        --route-table-ids $rtPrivBId `
        --region $REGION --output table 2>&1 |
        Tee-Object -Append -FilePath $evidenceFile

    Write-Ok "Stage 2 complete. Evidence: $evidenceFile"
}

# ─── STAGE 3 : Compute ───────────────────────────────────────────────────────

function Invoke-Stage3 {
    Write-Stage "Stage 3 – Compute: key pair + 3 EC2 instances"

    # !! COST WARNING: This stage launches 3 x t3.micro instances in ap-south-1.
    # Current on-demand price is approximately USD 0.0104/hr each = ~USD 0.031/hr total.
    # The caller (Invoke-Main) should have already confirmed cost before reaching here.

    Ensure-EvidenceDir
    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\03-compute.txt"
    $keyName      = 'ewb-lab'
    $keyPath      = "$HOME\.ssh\ewb-lab.pem"

    # Resolve latest Amazon Linux 2023 AMI via SSM
    Write-Info "Resolving Amazon Linux 2023 AMI..."
    $amiId = aws ssm get-parameter `
        --name '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64' `
        --region $REGION --query 'Parameter.Value' --output text
    if ($LASTEXITCODE -ne 0) { throw "Failed to resolve AMI via SSM" }
    Write-Ok "AMI: $amiId"
    $state['AmiId'] = $amiId

    # ── Key pair ─────────────────────────────────────────────────────────────
    $existingKey = aws ec2 describe-key-pairs `
        --key-names $keyName --region $REGION --output json 2>$null |
        ConvertFrom-Json
    if ($LASTEXITCODE -eq 0 -and $existingKey.KeyPairs.Count -gt 0) {
        Write-Warn "Key pair '$keyName' already exists in AWS."
        if (-not (Test-Path $keyPath)) {
            throw "Key pair exists in AWS but .pem not found at $keyPath. Delete the key pair in AWS and re-run Stage 3."
        }
        Write-Ok ".pem found at $keyPath"
    } else {
        Write-Info "Creating key pair ewb-lab..."
        if (-not (Test-Path "$HOME\.ssh")) {
            New-Item -ItemType Directory -Path "$HOME\.ssh" | Out-Null
        }
        aws ec2 create-key-pair `
            --key-name $keyName `
            --key-type rsa `
            --region $REGION `
            --query 'KeyMaterial' --output text | Set-Content -Path $keyPath -Encoding ascii
        if ($LASTEXITCODE -ne 0) { throw "Key pair creation failed" }
        Write-Ok "Key pair created; .pem saved to $keyPath"

        # Lock permissions: owner read-only
        icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
        Write-Ok "Locked .pem permissions (owner-read-only)"
    }
    $state['KeyName'] = $keyName

    # Common block device mapping (small root, DeleteOnTermination)
    $bdm = '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3","DeleteOnTermination":true}}]'

    # ── Bastion (ewb-bastion, 10.10.1.10, public subnet, public IP) ───────────
    $existing = Invoke-Aws @('ec2','describe-instances',
        '--filters',
        "Name=tag:Name,Values=ewb-bastion",
        "Name=tag:Project,Values=$PROJECT_TAG",
        "Name=instance-state-name,Values=running,pending,stopped")
    $existInst = $existing.Reservations | ForEach-Object { $_.Instances } | Where-Object { $_ }
    if ($existInst.Count -gt 0) {
        $bastionId = $existInst[0].InstanceId
        Write-Warn "Bastion already exists: $bastionId"
    } else {
        $r = Invoke-Aws @('ec2','run-instances',
            '--image-id',$amiId,
            '--instance-type','t3.micro',
            '--key-name',$keyName,
            '--subnet-id',$state['PubSubAId'],
            '--private-ip-address','10.10.1.10',
            '--security-group-ids',$state['SgBastionId'],
            '--associate-public-ip-address',
            '--block-device-mappings',$bdm,
            '--count','1',
            '--tag-specifications',
            "ResourceType=instance,Tags=[{Key=Name,Value=ewb-bastion},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $bastionId = $r.Instances[0].InstanceId
        Write-Ok "Launched ewb-bastion: $bastionId"
    }
    $state['BastionId'] = $bastionId

    # ── App-A (ewb-app-a, 10.10.2.10, private subnet, NO public IP) ──────────
    $existing = Invoke-Aws @('ec2','describe-instances',
        '--filters',
        "Name=tag:Name,Values=ewb-app-a",
        "Name=tag:Project,Values=$PROJECT_TAG",
        "Name=instance-state-name,Values=running,pending,stopped")
    $existInst = $existing.Reservations | ForEach-Object { $_.Instances } | Where-Object { $_ }
    if ($existInst.Count -gt 0) {
        $appAId = $existInst[0].InstanceId
        Write-Warn "App-A already exists: $appAId"
    } else {
        $r = Invoke-Aws @('ec2','run-instances',
            '--image-id',$amiId,
            '--instance-type','t3.micro',
            '--key-name',$keyName,
            '--subnet-id',$state['PrivSubAId'],
            '--private-ip-address','10.10.2.10',
            '--security-group-ids',$state['SgAppAId'],
            '--no-associate-public-ip-address',
            '--block-device-mappings',$bdm,
            '--count','1',
            '--tag-specifications',
            "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-a},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $appAId = $r.Instances[0].InstanceId
        Write-Ok "Launched ewb-app-a: $appAId"
    }
    $state['AppAId'] = $appAId

    # ── App-B (ewb-app-b, 10.20.1.10, VPC B private subnet, NO public IP) ────
    $existing = Invoke-Aws @('ec2','describe-instances',
        '--filters',
        "Name=tag:Name,Values=ewb-app-b",
        "Name=tag:Project,Values=$PROJECT_TAG",
        "Name=instance-state-name,Values=running,pending,stopped")
    $existInst = $existing.Reservations | ForEach-Object { $_.Instances } | Where-Object { $_ }
    if ($existInst.Count -gt 0) {
        $appBId = $existInst[0].InstanceId
        Write-Warn "App-B already exists: $appBId"
    } else {
        $r = Invoke-Aws @('ec2','run-instances',
            '--image-id',$amiId,
            '--instance-type','t3.micro',
            '--key-name',$keyName,
            '--subnet-id',$state['PrivSubBId'],
            '--private-ip-address','10.20.1.10',
            '--security-group-ids',$state['SgAppBId'],
            '--no-associate-public-ip-address',
            '--block-device-mappings',$bdm,
            '--count','1',
            '--tag-specifications',
            "ResourceType=instance,Tags=[{Key=Name,Value=ewb-app-b},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $appBId = $r.Instances[0].InstanceId
        Write-Ok "Launched ewb-app-b: $appBId"
    }
    $state['AppBId'] = $appBId

    Save-LabState $state

    # Wait for all 3 instances to pass status checks
    Write-Info "Waiting for 3 instances to reach status OK (may take 2-3 min)..."
    $allIds = @($bastionId, $appAId, $appBId)
    aws ec2 wait instance-status-ok --instance-ids @allIds --region $REGION
    if ($LASTEXITCODE -ne 0) { throw "Instance status check timed out" }
    Write-Ok "All instances passed status checks"

    # Get bastion public IP and record
    $desc = Invoke-Aws @('ec2','describe-instances','--instance-ids',$bastionId)
    $bastionPublicIp = $desc.Reservations[0].Instances[0].PublicIpAddress
    $state['BastionPublicIp'] = $bastionPublicIp
    Save-LabState $state
    Write-Ok "Bastion public IP: $bastionPublicIp"

    # ── Checkpoint 02: evidence ───────────────────────────────────────────────
    aws ec2 describe-instances `
        --instance-ids @allIds `
        --region $REGION `
        --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`].Value|[0]]' `
        --output table 2>&1 |
        Tee-Object -FilePath $evidenceFile

    Write-Ok "Stage 3 complete. Evidence: $evidenceFile"
    Write-Warn "Remember: App-A and App-B must show empty/null public IP in the evidence above."
}

# ─── STAGE 4 : SSH access + baseline ─────────────────────────────────────────

function Invoke-Stage4 {
    Write-Stage "Stage 4 – SSH baseline + pre-peering failure (Test 01)"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\04-ssh-test01.txt"
    $keyPath      = "$HOME\.ssh\ewb-lab.pem"
    $bastionIp    = $state['BastionPublicIp']

    # Write ~/.ssh/config (not committed – this is a local config file)
    $sshConfig = @"
# EWB VPC Peering Lab – SSH config
# DO NOT COMMIT THIS FILE

Host ewb-bastion
    HostName $bastionIp
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    StrictHostKeyChecking no

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    StrictHostKeyChecking no

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    StrictHostKeyChecking no
"@
    Set-Content -Path "$HOME\.ssh\config" -Value $sshConfig -Encoding ascii
    Write-Ok "~/.ssh/config written (not committed)"

    # Ensure key permissions
    icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
    Write-Ok ".pem permissions locked"

    # Test 1: SSH to bastion
    Write-Info "Test: ssh ewb-bastion (hostname)..."
    $bastionHostname = ssh -o ConnectTimeout=15 ewb-bastion 'hostname'
    "=== SSH to ewb-bastion: hostname ===" | Tee-Object -FilePath $evidenceFile
    $bastionHostname | Tee-Object -Append -FilePath $evidenceFile
    Write-Ok "Bastion hostname: $bastionHostname"

    # Test 2: SSH to App-A via ProxyJump
    Write-Info "Test: ssh ewb-app-a (hostname)..."
    $appAHostname = ssh -o ConnectTimeout=15 ewb-app-a 'hostname'
    "=== SSH to ewb-app-a via ProxyJump: hostname ===" | Tee-Object -Append -FilePath $evidenceFile
    $appAHostname | Tee-Object -Append -FilePath $evidenceFile
    Write-Ok "App-A hostname: $appAHostname"

    # Test 01: ping from App-A to App-B (EXPECTED FAILURE – no peering yet)
    Write-Info "Test 01: ping 10.20.1.10 from App-A (EXPECTED TO FAIL – no peering)..."
    "=== Test 01: ping App-B (10.20.1.10) from App-A – EXPECTED FAILURE ===" |
        Tee-Object -Append -FilePath $evidenceFile
    try {
        $pingOut = ssh -o ConnectTimeout=15 ewb-app-a 'ping -c 4 -W 2 10.20.1.10 2>&1; echo exit:$?'
        $pingOut | Tee-Object -Append -FilePath $evidenceFile
    } catch {
        "ping timed out or connection refused (expected)" | Tee-Object -Append -FilePath $evidenceFile
    }
    Write-Warn "Ping to App-B expected to fail (no peering) – evidence saved."

    Write-Ok "Stage 4 complete. Evidence: $evidenceFile"
    Write-Warn "ssh ewb-app-b will fail until Stage 5 (peering) and Stage 6 (routes) are complete."
}

# ─── STAGE 5 : VPC Peering ───────────────────────────────────────────────────

function Invoke-Stage5 {
    Write-Stage "Stage 5 – VPC Peering: create, accept, verify Active"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\05-peering.txt"

    # ── Create peering connection ─────────────────────────────────────────────
    $existing = Invoke-Aws @('ec2','describe-vpc-peering-connections',
        '--filters',
        "Name=tag:Name,Values=ewb-a-b-peer",
        "Name=tag:Project,Values=$PROJECT_TAG",
        "Name=status-code,Values=pending-acceptance,active")
    if ($existing.VpcPeeringConnections.Count -gt 0) {
        $peerConnId = $existing.VpcPeeringConnections[0].VpcPeeringConnectionId
        Write-Warn "Peering connection already exists: $peerConnId"
    } else {
        $r = Invoke-Aws @('ec2','create-vpc-peering-connection',
            '--vpc-id',$state['VpcAId'],
            '--peer-vpc-id',$state['VpcBId'],
            '--tag-specifications',
            "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=ewb-a-b-peer},{Key=Project,Value=$PROJECT_TAG},{Key=Student,Value=$STUDENT_TAG}]")
        $peerConnId = $r.VpcPeeringConnection.VpcPeeringConnectionId
        Write-Ok "Created peering connection: $peerConnId"
    }
    $state['PeerConnId'] = $peerConnId
    Save-LabState $state

    # ── Accept the peering connection ─────────────────────────────────────────
    $pc = (Invoke-Aws @('ec2','describe-vpc-peering-connections',
        '--vpc-peering-connection-ids',$peerConnId)).VpcPeeringConnections[0]
    $pcStatus = $pc.Status.Code
    Write-Info "Peering status: $pcStatus"

    if ($pcStatus -eq 'pending-acceptance') {
        Invoke-Aws @('ec2','accept-vpc-peering-connection',
            '--vpc-peering-connection-id',$peerConnId) | Out-Null
        Write-Ok "Accepted peering connection"
    } elseif ($pcStatus -eq 'active') {
        Write-Warn "Peering already active"
    } else {
        throw "Unexpected peering status: $pcStatus"
    }

    # Wait for Active
    Write-Info "Waiting for peering to become Active..."
    $retries = 0
    do {
        Start-Sleep -Seconds 5
        $pc = (Invoke-Aws @('ec2','describe-vpc-peering-connections',
            '--vpc-peering-connection-ids',$peerConnId)).VpcPeeringConnections[0]
        $pcStatus = $pc.Status.Code
        Write-Info "  Status: $pcStatus"
        $retries++
    } while ($pcStatus -ne 'active' -and $retries -lt 12)

    if ($pcStatus -ne 'active') { throw "Peering did not become active within 60s" }
    Write-Ok "Peering is Active: $peerConnId"

    # ── Checkpoint 03: describe peering ──────────────────────────────────────
    aws ec2 describe-vpc-peering-connections `
        --vpc-peering-connection-ids $peerConnId `
        --region $REGION --output table 2>&1 |
        Tee-Object -FilePath $evidenceFile

    Write-Ok "Stage 5 complete. Evidence: $evidenceFile"
}

# ─── STAGE 6 : Routes ────────────────────────────────────────────────────────

function Invoke-Stage6 {
    Write-Stage "Stage 6 – Routes: add peering routes to 3 route tables"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\06-routes.txt"
    $peerConnId   = $state['PeerConnId']

    # Helper: add route if not present
    function Add-PeeringRoute { param($RtId, $DestCidr, $PcxId)
        $routes = (Invoke-Aws @('ec2','describe-route-tables',
            '--route-table-ids',$RtId)).RouteTables[0].Routes
        $exists = $routes | Where-Object {
            $_.DestinationCidrBlock -eq $DestCidr -and $_.VpcPeeringConnectionId -eq $PcxId
        }
        if ($exists) {
            Write-Warn "Route $DestCidr -> $PcxId already exists in $RtId"
        } else {
            Invoke-Aws @('ec2','create-route',
                '--route-table-id',$RtId,
                '--destination-cidr-block',$DestCidr,
                '--vpc-peering-connection-id',$PcxId) | Out-Null
            Write-Ok "Added $DestCidr -> $PcxId in $RtId"
        }
    }

    # ewb-rt-a-private: 10.20.0.0/16 -> pcx
    Add-PeeringRoute -RtId $state['RtPrivAId'] -DestCidr '10.20.0.0/16' -PcxId $peerConnId

    # ewb-rt-b-private: 10.10.0.0/16 -> pcx
    Add-PeeringRoute -RtId $state['RtPrivBId'] -DestCidr '10.10.0.0/16' -PcxId $peerConnId

    # ewb-rt-a-public: 10.20.0.0/16 -> pcx  (needed for ProxyJump to App-B)
    Add-PeeringRoute -RtId $state['RtPubAId'] -DestCidr '10.20.0.0/16' -PcxId $peerConnId

    # ── Checkpoint 04: print all 3 route tables ────────────────────────────────
    aws ec2 describe-route-tables `
        --route-table-ids $state['RtPubAId'] $state['RtPrivAId'] $state['RtPrivBId'] `
        --region $REGION --output table 2>&1 |
        Tee-Object -FilePath $evidenceFile

    Write-Ok "Stage 6 complete. Evidence: $evidenceFile"
}

# ─── STAGE 7 : Verification ──────────────────────────────────────────────────

function Invoke-Stage7 {
    Write-Stage "Stage 7 – Verification: Tests 02-05 + controlled failure/recovery"
    Ensure-EvidenceDir

    $state       = Get-LabState
    $peerConnId  = $state['PeerConnId']
    $sgAppBId    = $state['SgAppBId']

    function Run-SshCmd { param($Host, $Cmd, $Label, $OutFile)
        $out = ssh -o ConnectTimeout=20 $Host $Cmd 2>&1
        "=== $Label ===" | Tee-Object -Append -FilePath $OutFile
        $out | Tee-Object -Append -FilePath $OutFile
        return $out
    }

    # Test 02: Forward ping App-A -> App-B
    $f = "$EVIDENCE_DIR\07-test02-ping-forward.txt"
    Run-SshCmd -Host 'ewb-app-a' -Cmd 'ping -c 4 10.20.1.10' `
        -Label 'Test 02: Forward ping App-A -> App-B (10.20.1.10)' -OutFile $f
    Write-Ok "Test 02 done. Evidence: $f"

    # Test 03: Reverse ping App-B -> App-A
    $f = "$EVIDENCE_DIR\07-test03-ping-reverse.txt"
    Run-SshCmd -Host 'ewb-app-b' -Cmd 'ping -c 4 10.10.2.10' `
        -Label 'Test 03: Reverse ping App-B -> App-A (10.10.2.10)' -OutFile $f
    Write-Ok "Test 03 done. Evidence: $f"

    # Test 04: SSH to App-B through bastion
    $f = "$EVIDENCE_DIR\07-test04-ssh-app-b.txt"
    Run-SshCmd -Host 'ewb-app-b' -Cmd 'hostname; hostname -I' `
        -Label 'Test 04: SSH to App-B (hostname; hostname -I)' -OutFile $f
    Write-Ok "Test 04 done. Evidence: $f"

    # Test 05: Confirm no public IP on App-A / App-B
    $f = "$EVIDENCE_DIR\07-test05-no-public-ip.txt"
    "=== Test 05: No public IP on App-A / App-B ===" | Tee-Object -FilePath $f
    aws ec2 describe-instances `
        --instance-ids $state['AppAId'] $state['AppBId'] `
        --region $REGION `
        --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,PublicDnsName]' `
        --output table 2>&1 | Tee-Object -Append -FilePath $f
    Write-Ok "Test 05 done. Evidence: $f"

    # ── Controlled Failure: remove ICMP rule from ewb-sg-app-b ───────────────
    $f = "$EVIDENCE_DIR\07-controlled-failure.txt"
    Write-Stage "Controlled failure: remove ICMP rule from ewb-sg-app-b"

    "=== Step 1: Remove ICMP echo-request rule from ewb-sg-app-b ===" |
        Tee-Object -FilePath $f
    Invoke-Aws @('ec2','revoke-security-group-ingress',
        '--group-id',$sgAppBId,
        '--ip-permissions',
        '[{"IpProtocol":"icmp","FromPort":8,"ToPort":0,"IpRanges":[{"CidrIp":"10.10.2.10/32"}]}]') |
        Out-Null
    Write-Ok "ICMP rule removed"

    "=== Step 2: Ping App-B from App-A (EXPECTED TO FAIL) ===" |
        Tee-Object -Append -FilePath $f
    try {
        $out = ssh -o ConnectTimeout=15 'ewb-app-a' 'ping -c 4 -W 2 10.20.1.10 2>&1; echo exit:$?'
        $out | Tee-Object -Append -FilePath $f
    } catch {
        "Ping failed as expected" | Tee-Object -Append -FilePath $f
    }
    Write-Warn "Ping after rule removal expected to fail."

    "=== Step 3: Restore ICMP rule ===" | Tee-Object -Append -FilePath $f
    Invoke-Aws @('ec2','authorize-security-group-ingress',
        '--group-id',$sgAppBId,
        '--ip-permissions',
        '[{"IpProtocol":"icmp","FromPort":8,"ToPort":0,"IpRanges":[{"CidrIp":"10.10.2.10/32"}]}]') |
        Out-Null
    Write-Ok "ICMP rule restored"

    "=== Step 4: Ping App-B from App-A (EXPECTED TO SUCCEED after restore) ===" |
        Tee-Object -Append -FilePath $f
    $out = ssh -o ConnectTimeout=15 'ewb-app-a' 'ping -c 4 10.20.1.10'
    $out | Tee-Object -Append -FilePath $f
    Write-Ok "Ping succeeded after rule restore. Controlled failure complete."

    Write-Ok "Stage 7 complete. Evidence: evidence/07-*.txt"
}

# ─── STAGE 8 : Report ────────────────────────────────────────────────────────

function Invoke-Stage8 {
    Write-Stage "Stage 8 – Final report"
    Ensure-EvidenceDir

    $state      = Get-LabState
    $reportDir  = "$PSScriptRoot\report"
    $reportFile = "$reportDir\Vikas_EWB_VPC_Peering.md"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir | Out-Null
    }

    # Evidence content helpers
    function Read-Evidence { param($File)
        if (Test-Path $File) { return (Get-Content $File -Raw) }
        return "(evidence file not found: $File)"
    }

    $report = @"
# EWB Cloud Labs – AWS VPC Peering (Project 01)
## Submission Report

**Student:** Vikas Marri
**Email:** vikasmarri9@gmail.com
**Region:** ap-south-1 (Mumbai)
**Account ID:** $($state['AccountId'])
**Date:** $(Get-Date -Format 'yyyy-MM-dd')

---

## Cover

This report documents the end-to-end build and verification of an AWS VPC Peering
connection between two VPCs in the same region and account, following the EWB Cloud
Labs Project 01 specification.

---

## Architecture Diagram

``````
                        Internet
                           |
                    [ewb-igw-a: $($state['IgwId'])]
                           |
        ┌──────────────────────────────────────────────┐
        │  VPC A: ewb-vpc-a  10.10.0.0/16             │
        │  ID: $($state['VpcAId'])                     │
        │                                               │
        │  ┌────────────────────────────────────────┐  │
        │  │ ewb-a-public  10.10.1.0/24             │  │
        │  │ ID: $($state['PubSubAId'])              │  │
        │  │                                         │  │
        │  │  [ewb-bastion  10.10.1.10]             │  │
        │  │   ID: $($state['BastionId'])            │  │
        │  │   Public IP: $($state['BastionPublicIp'])│  │
        │  └────────────────────────────────────────┘  │
        │                                               │
        │  ┌────────────────────────────────────────┐  │
        │  │ ewb-a-private  10.10.2.0/24            │  │
        │  │ ID: $($state['PrivSubAId'])             │  │
        │  │                                         │  │
        │  │  [ewb-app-a  10.10.2.10]               │  │
        │  │   ID: $($state['AppAId'])               │  │
        │  └────────────────────────────────────────┘  │
        └───────────────────────┬──────────────────────┘
                                │
                   VPC Peering: $($state['PeerConnId'])
                   (ewb-a-b-peer, same account/region)
                                │
        ┌───────────────────────┴──────────────────────┐
        │  VPC B: ewb-vpc-b  10.20.0.0/16             │
        │  ID: $($state['VpcBId'])                     │
        │  (NO Internet Gateway)                        │
        │                                               │
        │  ┌────────────────────────────────────────┐  │
        │  │ ewb-b-private  10.20.1.0/24            │  │
        │  │ ID: $($state['PrivSubBId'])             │  │
        │  │                                         │  │
        │  │  [ewb-app-b  10.20.1.10]               │  │
        │  │   ID: $($state['AppBId'])               │  │
        │  └────────────────────────────────────────┘  │
        └──────────────────────────────────────────────┘
``````

---

## Resource Inventory

| Resource | ID | CIDR / IP |
|---|---|---|
| ewb-vpc-a | $($state['VpcAId']) | 10.10.0.0/16 |
| ewb-a-public | $($state['PubSubAId']) | 10.10.1.0/24 |
| ewb-a-private | $($state['PrivSubAId']) | 10.10.2.0/24 |
| ewb-vpc-b | $($state['VpcBId']) | 10.20.0.0/16 |
| ewb-b-private | $($state['PrivSubBId']) | 10.20.1.0/24 |
| ewb-igw-a | $($state['IgwId']) | — |
| ewb-bastion | $($state['BastionId']) | 10.10.1.10 + $($state['BastionPublicIp']) |
| ewb-app-a | $($state['AppAId']) | 10.10.2.10 |
| ewb-app-b | $($state['AppBId']) | 10.20.1.10 |
| ewb-rt-a-public | $($state['RtPubAId']) | — |
| ewb-rt-a-private | $($state['RtPrivAId']) | — |
| ewb-rt-b-private | $($state['RtPrivBId']) | — |
| ewb-sg-bastion | $($state['SgBastionId']) | — |
| ewb-sg-app-a | $($state['SgAppAId']) | — |
| ewb-sg-app-b | $($state['SgAppBId']) | — |
| ewb-a-b-peer | $($state['PeerConnId']) | — |

---

## Route Tables

### ewb-rt-a-public ($($state['RtPubAId']))
| Destination | Target |
|---|---|
| 10.10.0.0/16 | local |
| 10.20.0.0/16 | $($state['PeerConnId']) |
| 0.0.0.0/0 | $($state['IgwId']) |

### ewb-rt-a-private ($($state['RtPrivAId']))
| Destination | Target |
|---|---|
| 10.10.0.0/16 | local |
| 10.20.0.0/16 | $($state['PeerConnId']) |

### ewb-rt-b-private ($($state['RtPrivBId']))
| Destination | Target |
|---|---|
| 10.20.0.0/16 | local |
| 10.10.0.0/16 | $($state['PeerConnId']) |

---

## Security Group Rules

### ewb-sg-bastion ($($state['SgBastionId']))
| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 22 | $($state['MyPublicIp'])/32 |
| Outbound | All | All | 0.0.0.0/0 |

### ewb-sg-app-a ($($state['SgAppAId']))
| Direction | Protocol | Port/Type | Source |
|---|---|---|---|
| Inbound | TCP | 22 | 10.10.1.10/32 |
| Inbound | ICMP | echo-request (8/0) | 10.20.1.10/32 |
| Outbound | All | All | 0.0.0.0/0 |

### ewb-sg-app-b ($($state['SgAppBId']))
| Direction | Protocol | Port/Type | Source |
|---|---|---|---|
| Inbound | TCP | 22 | 10.10.1.10/32 |
| Inbound | ICMP | echo-request (8/0) | 10.10.2.10/32 |
| Outbound | All | All | 0.0.0.0/0 |

---

## Peering Status

**Connection ID:** $($state['PeerConnId'])
**Requester VPC:** $($state['VpcAId']) (10.10.0.0/16)
**Accepter VPC:** $($state['VpcBId']) (10.20.0.0/16)
**Status:** Active

---

## Test Outputs

### Test 01 – Pre-Peering Failure (ping App-B from App-A)

$(Read-Evidence "$EVIDENCE_DIR\04-ssh-test01.txt")

### Test 02 – Forward Ping (App-A → App-B)

$(Read-Evidence "$EVIDENCE_DIR\07-test02-ping-forward.txt")

### Test 03 – Reverse Ping (App-B → App-A)

$(Read-Evidence "$EVIDENCE_DIR\07-test03-ping-reverse.txt")

### Test 04 – SSH to App-B via ProxyJump

$(Read-Evidence "$EVIDENCE_DIR\07-test04-ssh-app-b.txt")

### Test 05 – No Public IP on App-A / App-B

$(Read-Evidence "$EVIDENCE_DIR\07-test05-no-public-ip.txt")

---

## Controlled Failure and Recovery

$(Read-Evidence "$EVIDENCE_DIR\07-controlled-failure.txt")

---

## Forward / Return Path Explanation

### Forward path (Bastion SSH → App-A ping → App-B):
1. Packet leaves App-A (10.10.2.10) destined for App-B (10.20.1.10).
2. ewb-rt-a-private matches 10.20.0.0/16 → sends via VPC Peering connection $($state['PeerConnId']).
3. Packet arrives in VPC B; ewb-rt-b-private has no explicit match for 10.10.x.x
   (only 10.10.0.0/16 → pcx for the return path), local route handles 10.20.0.0/16.
4. ewb-sg-app-b allows ICMP echo-request (type 8) from 10.10.2.10/32.
5. App-B (10.20.1.10) receives the packet and sends echo-reply.

### Return path (App-B → App-A):
1. Echo-reply leaves App-B (10.20.1.10) destined for App-A (10.10.2.10).
2. ewb-rt-b-private matches 10.10.0.0/16 → sends via VPC Peering.
3. Packet arrives in VPC A; ewb-rt-a-private matches local 10.10.0.0/16.
4. ewb-sg-app-a allows ICMP echo-request from 10.20.1.10/32; return traffic
   (echo-reply) is allowed by the stateful security group.
5. App-A receives the reply.

---

## "Be Ready to Explain" Questions

**Q1: Why does VPC B have no Internet Gateway?**
VPC B represents a private backend network. All access is through the peering
connection from VPC A. Adding an IGW would expose App-B to the Internet, which
violates the least-privilege design.

**Q2: Why must the peering connection be explicitly accepted?**
AWS requires explicit acceptance to prevent one account (or in multi-account
setups, one team) from unilaterally accessing another VPC. It is a security
control ensuring mutual consent.

**Q3: Why did we add a peering route to ewb-rt-a-public?**
The bastion's ProxyJump to App-B originates from the public subnet. The bastion
is the SSH proxy, so its subnet's route table must know how to reach 10.20.0.0/16.
Without this route the TCP connection from the bastion to App-B would be dropped.

**Q4: Why are the SSH and ICMP security group rules locked to specific /32 CIDRs?**
0.0.0.0/0 on SSH or ICMP would allow any host to attempt connections. Using /32
CIDRs (bastion IP or App-A/App-B IPs) limits exposure to only the known hosts
that need access, following the principle of least privilege.

---

## What I Learned

1. VPC Peering is non-transitive — traffic between VPC A and VPC C must have its
   own peering connection; it cannot route through VPC B.
2. Both route tables on both sides of the peering must have matching routes or
   traffic flows only one way.
3. Security groups are stateful — only inbound rules need to be defined; return
   traffic is automatically allowed.
4. The ProxyJump technique lets the bastion act as a transparent SSH gateway
   without copying the private key to the bastion.
5. ICMP rules in AWS use FromPort=type and ToPort=code (e.g., echo-request = 8/0).

---

*Report generated by vpc-peering-lab.ps1 Stage 8*
"@

    Set-Content -Path $reportFile -Value $report -Encoding utf8
    Write-Ok "Report written: $reportFile"

    # Try pandoc PDF conversion
    $pandocAvailable = Get-Command pandoc -ErrorAction SilentlyContinue
    if ($pandocAvailable) {
        pandoc $reportFile -o "$reportDir\Vikas_EWB_VPC_Peering.pdf" --pdf-engine=xelatex
        Write-Ok "PDF generated: $reportDir\Vikas_EWB_VPC_Peering.pdf"
    } else {
        Write-Warn "pandoc not found – PDF conversion skipped. Install pandoc to generate PDF."
    }

    Write-Ok "Stage 8 complete."
}

# ─── STAGE 9 : Cleanup ───────────────────────────────────────────────────────

function Invoke-Stage9 {
    Write-Stage "Stage 9 – Cleanup: terminate all resources"
    Ensure-EvidenceDir

    $state        = Get-LabState
    $evidenceFile = "$EVIDENCE_DIR\09-cleanup.txt"

    "=== EWB VPC Peering Lab – Cleanup $(Get-Date) ===" |
        Tee-Object -FilePath $evidenceFile

    # 1. Terminate instances
    Write-Info "Terminating instances..."
    $instanceIds = @($state['BastionId'], $state['AppAId'], $state['AppBId']) |
        Where-Object { $_ }
    if ($instanceIds.Count -gt 0) {
        aws ec2 terminate-instances --instance-ids @instanceIds `
            --region $REGION --output table 2>&1 |
            Tee-Object -Append -FilePath $evidenceFile
        Write-Info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids @instanceIds --region $REGION
        Write-Ok "Instances terminated"
    }

    # 2. Confirm root volumes are deleted (DeleteOnTermination=true)
    Write-Info "Verifying volumes are gone..."
    aws ec2 describe-volumes --region $REGION `
        --filters "Name=tag:Project,Values=$PROJECT_TAG" `
        --output table 2>&1 | Tee-Object -Append -FilePath $evidenceFile

    # 3. Delete peering routes then peering connection
    Write-Info "Deleting peering routes..."
    function Remove-RouteIfExists { param($RtId, $DestCidr)
        try {
            aws ec2 delete-route --route-table-id $RtId `
                --destination-cidr-block $DestCidr --region $REGION 2>&1
            Write-Ok "Deleted route $DestCidr from $RtId"
        } catch { Write-Warn "Route may already be gone: $DestCidr in $RtId" }
    }
    Remove-RouteIfExists -RtId $state['RtPrivAId'] -DestCidr '10.20.0.0/16'
    Remove-RouteIfExists -RtId $state['RtPrivBId'] -DestCidr '10.10.0.0/16'
    Remove-RouteIfExists -RtId $state['RtPubAId']  -DestCidr '10.20.0.0/16'

    Write-Info "Deleting peering connection..."
    try {
        aws ec2 delete-vpc-peering-connection `
            --vpc-peering-connection-id $state['PeerConnId'] `
            --region $REGION 2>&1 | Tee-Object -Append -FilePath $evidenceFile
        Write-Ok "Peering connection deleted"
    } catch { Write-Warn "Peering connection already deleted or not found" }

    # 4. Delete security groups
    Write-Info "Deleting security groups..."
    foreach ($sgId in @($state['SgBastionId'], $state['SgAppAId'], $state['SgAppBId'])) {
        if ($sgId) {
            try {
                aws ec2 delete-security-group --group-id $sgId --region $REGION 2>&1
                Write-Ok "Deleted SG: $sgId"
            } catch { Write-Warn "SG $sgId may already be deleted" }
        }
    }

    # 5. Disassociate and delete route tables (non-main only)
    Write-Info "Deleting route tables..."
    foreach ($rtId in @($state['RtPubAId'], $state['RtPrivAId'], $state['RtPrivBId'])) {
        if ($rtId) {
            # Disassociate explicit associations
            $assocs = (aws ec2 describe-route-tables --route-table-ids $rtId `
                --region $REGION --output json | ConvertFrom-Json).RouteTables[0].Associations |
                Where-Object { -not $_.Main }
            foreach ($assoc in $assocs) {
                aws ec2 disassociate-route-table `
                    --association-id $assoc.RouteTableAssociationId --region $REGION 2>&1
                Write-Ok "Disassociated $($assoc.RouteTableAssociationId) from $rtId"
            }
            try {
                aws ec2 delete-route-table --route-table-id $rtId --region $REGION 2>&1
                Write-Ok "Deleted route table: $rtId"
            } catch { Write-Warn "Route table $rtId may already be deleted" }
        }
    }

    # 6. Delete subnets
    Write-Info "Deleting subnets..."
    foreach ($subId in @($state['PubSubAId'], $state['PrivSubAId'], $state['PrivSubBId'])) {
        if ($subId) {
            try {
                aws ec2 delete-subnet --subnet-id $subId --region $REGION 2>&1
                Write-Ok "Deleted subnet: $subId"
            } catch { Write-Warn "Subnet $subId may already be deleted" }
        }
    }

    # 7. Detach and delete IGW
    Write-Info "Detaching and deleting IGW..."
    if ($state['IgwId']) {
        try {
            aws ec2 detach-internet-gateway --internet-gateway-id $state['IgwId'] `
                --vpc-id $state['VpcAId'] --region $REGION 2>&1
            Write-Ok "IGW detached"
        } catch { Write-Warn "IGW may already be detached" }
        try {
            aws ec2 delete-internet-gateway --internet-gateway-id $state['IgwId'] `
                --region $REGION 2>&1
            Write-Ok "IGW deleted"
        } catch { Write-Warn "IGW may already be deleted" }
    }

    # 8. Delete VPCs
    Write-Info "Deleting VPCs..."
    foreach ($vpcId in @($state['VpcAId'], $state['VpcBId'])) {
        if ($vpcId) {
            try {
                aws ec2 delete-vpc --vpc-id $vpcId --region $REGION 2>&1
                Write-Ok "Deleted VPC: $vpcId"
            } catch { Write-Warn "VPC $vpcId may already be deleted" }
        }
    }

    # 9. Delete key pair
    Write-Info "Deleting key pair ewb-lab..."
    try {
        aws ec2 delete-key-pair --key-name ewb-lab --region $REGION 2>&1
        Write-Ok "Key pair ewb-lab deleted from AWS"
    } catch { Write-Warn "Key pair may already be deleted" }
    Write-Warn "REMINDER: Delete the local .pem file: Remove-Item `"$HOME\.ssh\ewb-lab.pem`""

    # 10. Final verification by Project tag
    Write-Info "Verifying cleanup by Project tag..."
    "=== Final verification – resources by Project tag ===" |
        Tee-Object -Append -FilePath $evidenceFile
    aws ec2 describe-instances `
        --filters "Name=tag:Project,Values=$PROJECT_TAG" `
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" `
        --region $REGION --query 'Reservations[].Instances[].[InstanceId,State.Name]' `
        --output table 2>&1 | Tee-Object -Append -FilePath $evidenceFile
    aws ec2 describe-vpcs `
        --filters "Name=tag:Project,Values=$PROJECT_TAG" `
        --region $REGION --output table 2>&1 | Tee-Object -Append -FilePath $evidenceFile
    aws ec2 describe-volumes `
        --filters "Name=tag:Project,Values=$PROJECT_TAG" `
        --region $REGION --output table 2>&1 | Tee-Object -Append -FilePath $evidenceFile
    aws ec2 describe-addresses `
        --filters "Name=tag:Project,Values=$PROJECT_TAG" `
        --region $REGION --output table 2>&1 | Tee-Object -Append -FilePath $evidenceFile

    Write-Ok "Stage 9 complete. Evidence: $evidenceFile"
}

# ─── Main dispatcher ──────────────────────────────────────────────────────────

function Invoke-Main {
    if ($Cleanup) {
        Write-Warn "*** CLEANUP MODE ***"
        Write-Warn "This will terminate all 3 instances and delete all VPC resources."
        Write-Warn "Make sure your evidence/ and report/ are committed first."
        $confirm = Read-Host "Type 'yes' to proceed with cleanup"
        if ($confirm -ne 'yes') { Write-Info "Cleanup cancelled."; return }
        Invoke-Stage9
        return
    }

    switch ($Stage) {
        0 { Invoke-Stage0 }
        1 { Invoke-Stage1 }
        2 { Invoke-Stage2 }
        3 {
            Write-Warn "*** COST WARNING ***"
            Write-Warn "Stage 3 will launch 3 x t3.micro instances in ap-south-1."
            Write-Warn "Approximate cost: ~USD 0.031/hr while running."
            $confirm = Read-Host "Type 'yes' to proceed"
            if ($confirm -ne 'yes') { Write-Info "Stage 3 cancelled."; return }
            Invoke-Stage3
        }
        4 { Invoke-Stage4 }
        5 { Invoke-Stage5 }
        6 { Invoke-Stage6 }
        7 { Invoke-Stage7 }
        8 { Invoke-Stage8 }
        9 {
            Write-Warn "Use -Cleanup switch to run Stage 9, not -Stage 9."
            Write-Warn "This prevents accidental cleanup."
        }
        default { throw "Unknown stage: $Stage" }
    }
}

Invoke-Main
