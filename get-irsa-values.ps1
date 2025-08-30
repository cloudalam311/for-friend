Write-Host "=== IRSA Configuration Values Collector ===" -ForegroundColor Green
Write-Host ""

# Get AWS Account ID
Write-Host "1. Getting AWS Account ID..." -ForegroundColor Yellow
try {
    $AccountId = aws sts get-caller-identity --query Account --output text 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Account ID: $AccountId" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to get Account ID. Make sure AWS CLI is configured." -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to get Account ID. Make sure AWS CLI is configured." -ForegroundColor Red
}
Write-Host ""

# Get AWS Region
Write-Host "2. Getting current AWS Region..." -ForegroundColor Yellow
try {
    $Region = aws configure get region 2>$null
    if ([string]::IsNullOrEmpty($Region)) {
        $Region = aws ec2 describe-availability-zones --query 'AvailabilityZones[0].[RegionName]' --output text 2>$null
    }
    if (![string]::IsNullOrEmpty($Region)) {
        Write-Host "   ✅ Region: $Region" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to get Region. Please set it manually." -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to get Region. Please set it manually." -ForegroundColor Red
}
Write-Host ""

# List EKS Clusters
Write-Host "3. Listing EKS Clusters..." -ForegroundColor Yellow
try {
    aws eks list-clusters --query 'clusters' --output table 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ❌ Failed to list EKS clusters. Check permissions." -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to list EKS clusters. Check permissions." -ForegroundColor Red
}
Write-Host ""

$ClusterName = Read-Host "4. Please enter your EKS cluster name"
Write-Host ""

if (![string]::IsNullOrEmpty($ClusterName)) {
    # Get OIDC Provider URL
    Write-Host "5. Getting OIDC Provider details for cluster: $ClusterName" -ForegroundColor Yellow
    try {
        $OidcUrl = aws eks describe-cluster --name "$ClusterName" --query "cluster.identity.oidc.issuer" --output text 2>$null
        if ($LASTEXITCODE -eq 0 -and $OidcUrl -ne "None") {
            # Extract OIDC ID from URL
            $OidcId = $OidcUrl -replace 'https://oidc\.eks\..*\.amazonaws\.com/id/', ''
            Write-Host "   ✅ OIDC Issuer URL: $OidcUrl" -ForegroundColor Green
            Write-Host "   ✅ OIDC ID: $OidcId" -ForegroundColor Green
            
            # Construct full OIDC Provider ARN
            $OidcArn = "arn:aws:iam::$AccountId:oidc-provider/oidc.eks.$Region.amazonaws.com/id/$OidcId"
            Write-Host "   ✅ OIDC Provider ARN: $OidcArn" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Failed to get OIDC details for cluster: $ClusterName" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Failed to get OIDC details for cluster: $ClusterName" -ForegroundColor Red
    }
}
Write-Host ""

# Check for Service Catalog products
Write-Host "6. Looking for Service Catalog products..." -ForegroundColor Yellow
try {
    aws servicecatalog search-products --filters FullTextSearch="IRSA" --query 'ProductViewSummaries[*].[Name,ProductId]' --output table 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ❌ Failed to search Service Catalog. You may need to create the product first." -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Failed to search Service Catalog. You may need to create the product first." -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Summary for GitLab CI ===" -ForegroundColor Cyan
Write-Host ""
if (![string]::IsNullOrEmpty($AccountId) -and ![string]::IsNullOrEmpty($Region) -and ![string]::IsNullOrEmpty($OidcId)) {
    Write-Host "Replace these values in your .gitlab-ci.yml:" -ForegroundColor White
    Write-Host ""
    Write-Host "  <acct> → $AccountId" -ForegroundColor Yellow
    Write-Host "  <region> → $Region" -ForegroundColor Yellow
    Write-Host "  <oidc_id> → $OidcId" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Full OIDC Provider ARN:" -ForegroundColor White
    Write-Host "  $OidcArn" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "❌ Some values are missing. Please check the errors above." -ForegroundColor Red
}

Write-Host "For <artifact-id>, you'll need to:" -ForegroundColor White
Write-Host "1. Create a Service Catalog product from your CloudFormation template" -ForegroundColor White
Write-Host "2. Or use CloudFormation directly instead of Service Catalog" -ForegroundColor White
Write-Host ""
Write-Host "=== Alternative: Direct CloudFormation Approach ===" -ForegroundColor Cyan
Write-Host "Instead of Service Catalog, you could deploy directly with:" -ForegroundColor White
Write-Host ""
Write-Host "aws cloudformation deploy \\" -ForegroundColor Yellow
Write-Host "  --template-file `"IRSA Role.yaml`" \\" -ForegroundColor Yellow
Write-Host "  --stack-name astronomer-irsa-role \\" -ForegroundColor Yellow
Write-Host "  --parameter-overrides \\" -ForegroundColor Yellow
Write-Host "    ClusterOIDCProviderArn=$OidcArn \\" -ForegroundColor Yellow
Write-Host "    Namespace=astronomer \\" -ForegroundColor Yellow
Write-Host "    ServiceAccountName=astronomer-sa \\" -ForegroundColor Yellow
Write-Host "  --capabilities CAPABILITY_NAMED_IAM" -ForegroundColor Yellow
