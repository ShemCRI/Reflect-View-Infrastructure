region   = "us-east-1"
env_name = "cri-ct-rv-shared"

# Account IDs that need access to the DB migration bucket
cross_account_principals = [
  "arn:aws:iam::109743757398:root"  # cri-ct-rv-prod1 account
]

