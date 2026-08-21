resource "aws_ecr_repository" "noteapp" {
  name                 = "noteapp"
  image_tag_mutability = "IMMUTABLE" # every branch/commit gets its own tag — never overwrite one in place

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "noteapp"
  }
}

# Bound storage cost: ephemeral-env images churn constantly (new tag per
# commit on every active branch) — without this, old ones accumulate forever.
resource "aws_ecr_lifecycle_policy" "noteapp" {
  repository = aws_ecr_repository.noteapp.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire ephemeral-env images older than 14 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["env-"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent 20 main-branch images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      },
    ]
  })
}
