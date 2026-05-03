# katlauze.dev

Personal site and blog. Built with FastAPI, Jinja2 templates, and markdown files. Terminal-themed, easy to retheme.

## Stack

- **Backend:** FastAPI + Uvicorn / Gunicorn
- **Templates:** Jinja2
- **Content:** Markdown with YAML frontmatter
- **Email:** fastapi-mail via SendGrid SMTP
- **Containers:** Docker + Docker Compose
- **Deployment:** Azure Container Apps + AWS App Runner

## Running locally

**With Docker:**
```bash
make dev        # build + start with live reload
make dev-down   # stop
```

**Without Docker:**
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```
→ http://localhost:8000

## Environment variables

Copy `.env.example` to `.env` and fill in:

```
MAIL_USERNAME=apikey
MAIL_PASSWORD=your-sendgrid-api-key
MAIL_FROM=hello@yourdomain.com
MAIL_TO=you@yourdomain.com
```

The contact form degrades gracefully if these are missing.

## Adding a post

1. Copy `app/post_template/template.md` → `app/posts/your-post.md`
2. Fill in the frontmatter:

```yaml
---
title: "Post Title"
date: "YYYY-MM-DD"
slug: "url-friendly-slug"
summary: "Short description shown in post cards"
image: "/static/assets/images/filename.jpg"
---
```

3. Write the body in markdown. The post appears automatically, sorted by date.

## Deployment

Both pipelines trigger on push to `main` and use OIDC (no long-lived secrets stored in GitHub).

### Prerequisites

You only need these to run the one-time bootstrap scripts. Not needed for day-to-day dev.

**Azure bootstrap** — install Azure CLI and jq:
```bash
brew install azure-cli jq
az login
az account set --subscription <your-subscription-name-or-id>
```

**AWS bootstrap** — install AWS CLI, jq, and Docker (used to push a placeholder image to ECR):
```bash
brew install awscli jq
aws configure   # enter your Access Key ID, Secret, region
```

The IAM user running the bootstrap needs these permissions (one inline policy covers all of it — see the policy in the deployment section below):
- `ecr:*`
- `apprunner:*`
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:GetRole`, `iam:PassRole`
- `iam:CreateOpenIDConnectProvider`, `iam:ListOpenIDConnectProviders`

Verify both work:
```bash
az account show
aws sts get-caller-identity
```

### Azure Container Apps

**One-time setup:**
```bash
# edit the config block at the top first
./infra/bootstrap-azure.sh
```

The script creates the resource group, ACR, Container Apps environment, a service principal with OIDC federated credentials, and prints the exact values to paste into GitHub.

**Pipeline:** `az acr build` → push to ACR → update Container Apps revision.

**Where to paste the output:** GitHub repo → Settings → Secrets and variables → Actions

| Type | Name |
|---|---|
| Secret | `AZURE_CLIENT_ID` |
| Secret | `AZURE_TENANT_ID` |
| Secret | `AZURE_SUBSCRIPTION_ID` |
| Variable | `ACR_NAME` |
| Variable | `AZURE_RESOURCE_GROUP` |
| Variable | `CONTAINER_APP_NAME` |

### AWS App Runner

> **TODO by 2026-07-31:** AWS App Runner stopped accepting new customers on 2026-04-30. Existing services continue to work but no new features will be added. Migrate to ECS Express Mode (AWS recommended) or ECS Fargate before July end. See the migration guidance in the App Runner console.



**One-time setup:**
```bash
# edit the config block at the top first
./infra/bootstrap-aws.sh
```

The script creates the ECR repo, OIDC provider, two IAM roles (one for GitHub Actions, one for App Runner → ECR), pushes a placeholder image, and creates the App Runner service. It prints the exact values to paste into GitHub.

**Pipeline:** build image locally → push to ECR → `apprunner update-service` → wait for rollout.

**Where to paste the output:** GitHub repo → Settings → Secrets and variables → Actions

| Type | Name | 
|---|---|
| Secret | `AWS_ROLE_ARN` |
| Variable | `AWS_REGION` |
| Variable | `ECR_REPOSITORY` |
| Variable | `APPRUNNER_SERVICE_ARN` |

**Required IAM policy for the bootstrap user:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECR",
      "Effect": "Allow",
      "Action": "ecr:*",
      "Resource": "*"
    },
    {
      "Sid": "AppRunner",
      "Effect": "Allow",
      "Action": "apprunner:*",
      "Resource": "*"
    },
    {
      "Sid": "IAMBootstrap",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:GetRole",
        "iam:CreateOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Switching themes

Change one line in `app/templates/base.html`:

```html
<link rel="stylesheet" href="/static/css/themes/terminal.css" />
```

**Available themes:**

| File | Description |
|------|-------------|
| `terminal.css` | Dark background, green accent, monospace feel (default) |
| `light.css` | Light background, minimal |

All layout components (`main.css`) use CSS custom properties only — no hardcoded colours. Swapping the theme file is all that's needed.

**To create a new theme:**

1. Copy an existing theme file into `app/static/css/themes/`
2. Override the CSS variables at the top (`:root { --bg-page: …; --accent: …; }`)
3. Swap the `<link>` line in `base.html` to point to your new file

## Project structure

```
app/
  main.py               # Routes and app logic
  posts/                # Blog posts (.md files)
  post_template/        # Starter template for new posts
  static/
    css/
      main.css          # Layout — no hardcoded colours
      themes/           # terminal.css, light.css
    assets/images/
  templates/            # base, index, blog, about, post, contact, 404
Dockerfile              # Dev (uvicorn --reload)
Dockerfile.prod         # Prod (gunicorn, 4 workers)
docker-compose.yaml
docker-compose.prod.yaml
Makefile
requirements.txt
```

## Make targets

| Command         | Description                        |
|-----------------|------------------------------------|
| `make run`      | Local dev, no Docker (port 8000)   |
| `make dev`      | Docker dev with live reload        |
| `make dev-down` | Stop Docker dev                    |
| `make prod`     | Docker prod (Gunicorn)             |
| `make prod-down`| Stop prod                          |
| `make rebuild`  | Clean everything + restart dev     |
