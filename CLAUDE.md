# CLAUDE.md — katlauze personal site

Personal website for Katarzyna Lauzé. Built with FastAPI + Jinja2 + markdown-based blog. Terminal-themed, designed to be easy to retheme.

## Tech stack

- **Backend:** FastAPI (Python), Uvicorn / Gunicorn
- **Templates:** Jinja2
- **Blog content:** Markdown files with YAML frontmatter (`python-frontmatter`, `markdown2`)
- **Email:** fastapi-mail via SendGrid SMTP
- **Containerisation:** Docker + Docker Compose
- **Deployment:** Azure Container Apps + AWS App Runner (parallel pipelines)
- **CI/CD:** GitHub Actions with OIDC (no stored long-lived secrets)
- **Infra bootstrap:** `infra/bootstrap-azure.sh` and `infra/bootstrap-aws.sh`
- **Bootstrap prerequisites:** `azure-cli`, `awscli`, `jq`, Docker (AWS script pushes a placeholder image to ECR)
- **GitHub secrets/variables:** Settings → Secrets and variables → Actions (Secrets tab for sensitive values, Variables tab for config)

## Project structure

```
app/
  main.py               # All routes and app logic
  posts/                # Blog posts as .md files (YAML frontmatter + markdown body)
  post_template/        # Starter template for new posts
  static/
    css/
      main.css          # Layout only — zero hardcoded colours, all var(--xxx)
      themes/
        terminal.css    # Active theme (dark, green accent, monospace)
        light.css       # Alternate theme (swap one line in base.html to use)
    assets/images/      # All post and profile images
  templates/
    base.html           # Site shell: nav, footer, font imports, theme <link>
    index.html          # Homepage: hero + featured post + post grid
    blog.html           # Full post listing (/blog)
    about.html          # About page (renders about.md)
    post.html           # Individual post
    contact.html        # Contact form (SendGrid)
    404.html            # Not found page
Dockerfile              # Dev (Uvicorn --reload)
Dockerfile.prod         # Prod (Gunicorn, 4 workers)
docker-compose.yaml
docker-compose.prod.yaml
Makefile
requirements.txt
.env.example            # Copy to .env and fill in mail credentials
```

## Development commands

```bash
make run        # Local dev, no Docker: uvicorn --reload on :8000
make dev        # Docker dev with live reload
make dev-down   # Stop Docker dev
make prod       # Docker prod (Gunicorn)
make prod-down  # Stop prod
make rebuild    # Clean + restart dev
```

Without Docker:
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Routes

| Method | Path         | Description                                      |
|--------|--------------|--------------------------------------------------|
| GET    | `/`          | Homepage — featured post + post grid             |
| GET    | `/blog`      | Full post listing                                |
| GET    | `/about`     | About page (renders `app/posts/about.md`)        |
| GET    | `/post/{slug}` | Individual post (looked up by `slug` frontmatter) |
| GET    | `/contact`   | Contact form                                     |
| POST   | `/contact`   | Handle contact form submission (SendGrid)        |
| GET    | `/index.html`| 301 redirect to `/`                              |

## Blog post system

Posts live in `app/posts/` as `.md` files. `about.md` is special — rendered at `/about`, excluded from the blog grid.

Required frontmatter:
```yaml
---
title: "Post Title"
date: "YYYY-MM-DD"
slug: "url-friendly-slug"
summary: "Short description shown in post cards"
image: "/static/assets/images/filename.jpg"
---
```

To add a post: copy `app/post_template/template.md` → `app/posts/your-post.md`, fill in frontmatter, write body. No config needed — it appears automatically, sorted by date.

## Theme system

**To switch themes:** change one line in `app/templates/base.html`:
```html
<link rel="stylesheet" href="/static/css/themes/terminal.css" />
```
Swap `terminal.css` for `light.css` (or any new file in `themes/`).

`main.css` uses only CSS custom properties (`var(--bg-page)`, `var(--accent)`, etc.) — never hardcoded colours. Every component responds to the theme file automatically.

## Environment variables

Requires a `.env` file (gitignored) with:
```
MAIL_USERNAME=apikey
MAIL_PASSWORD=your-sendgrid-api-key
MAIL_FROM=hello@yourdomain.com
MAIL_TO=you@yourdomain.com
```

Contact form degrades gracefully if mail vars are missing (shows a config error instead of crashing).

## Key design decisions

- `about.md` is excluded from post listings via `exclude_slugs=["about-me"]` in `load_posts()`
- Post loading (`load_posts`) and slug lookup (`load_post_by_slug`) are separate functions in `main.py`
- The `markdown2` extras enabled: `fenced-code-blocks`, `code-friendly`, `tables`, `strike`
- Images from both original projects (sparrowsonline + sparrowrobotics) are merged into `static/assets/images/`
