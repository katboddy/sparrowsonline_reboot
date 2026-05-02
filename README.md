# katlauze.dev

Personal site and blog. Built with FastAPI, Jinja2 templates, and markdown files. Terminal-themed, easy to retheme.

## Stack

- **Backend:** FastAPI + Uvicorn / Gunicorn
- **Templates:** Jinja2
- **Content:** Markdown with YAML frontmatter
- **Email:** fastapi-mail via SendGrid SMTP
- **Containers:** Docker + Docker Compose
- **Deployment:** Azure Container Apps

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

### Azure Container Apps

**One-time setup:**
```bash
# edit the config block at the top first
./infra/bootstrap-azure.sh
```

The script creates the resource group, ACR, Container Apps environment, a service principal with OIDC federated credentials, and prints the exact secrets/variables to paste into GitHub.

**Pipeline:** `az acr build` → push to ACR → update Container Apps revision.

| GitHub Secrets | GitHub Variables |
|---|---|
| `AZURE_CLIENT_ID` | `ACR_NAME` |
| `AZURE_TENANT_ID` | `AZURE_RESOURCE_GROUP` |
| `AZURE_SUBSCRIPTION_ID` | `CONTAINER_APP_NAME` |

### AWS App Runner

**One-time setup:**
```bash
# edit the config block at the top first
./infra/bootstrap-aws.sh
```

The script creates the ECR repo, OIDC provider, two IAM roles (one for GitHub Actions, one for App Runner → ECR), and the App Runner service, then prints the exact secrets/variables to paste into GitHub.

**Pipeline:** build image locally → push to ECR → `apprunner update-service` → wait for rollout.

| GitHub Secrets | GitHub Variables |
|---|---|
| `AWS_ROLE_ARN` | `AWS_REGION` |
| | `ECR_REPOSITORY` |
| | `APPRUNNER_SERVICE_ARN` |

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
