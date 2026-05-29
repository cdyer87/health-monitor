# The Primary Provider (East Coast)
# If we don't specify an alias, Terraform defaults to this one.
provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Project     = "health-monitor"
      Environment = terraform.workspace
    }
  }
}

# The Secondary Backup Provider (West Coast)
# We must explicitly use the 'alias' keyword to call this provider.
provider "aws" {
  alias  = "west"
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "health-monitor"
      Environment = terraform.workspace
    }
  }
}