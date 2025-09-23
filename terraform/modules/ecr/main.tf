variable "repos" { type = list(string) }

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repos)
  name     = each.value
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

output "repo_urls" {
  value = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
