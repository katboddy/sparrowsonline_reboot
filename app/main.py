from datetime import datetime
from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from pydantic import SecretStr
from dotenv import load_dotenv
import os
import markdown2
import frontmatter
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

# ── Email ──────────────────────────────────────────────────────────────────
def make_mail_config() -> ConnectionConfig | None:
    """Return a mail config if all env vars are set, else None (graceful degradation)."""
    required = ["MAIL_USERNAME", "MAIL_PASSWORD", "MAIL_FROM", "MAIL_TO"]
    if not all(os.getenv(k) for k in required):
        logger.warning("Mail env vars not fully set — contact form will be disabled.")
        return None
    return ConnectionConfig(
        MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
        MAIL_PASSWORD=SecretStr(os.getenv("MAIL_PASSWORD")),
        MAIL_FROM=os.getenv("MAIL_FROM"),
        MAIL_PORT=587,
        MAIL_SERVER="smtp.sendgrid.net",
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
    )

mail_conf = make_mail_config()
fastmail = FastMail(mail_conf) if mail_conf else None

# ── App ────────────────────────────────────────────────────────────────────
app = FastAPI(docs_url=None, redoc_url=None)

app.mount("/static", StaticFiles(directory="app/static"), name="static")
templates = Jinja2Templates(directory="app/templates")

POSTS_DIR = "app/posts"

# ── Post loading ───────────────────────────────────────────────────────────
def load_posts(exclude_slugs: list[str] | None = None) -> tuple[dict | None, list[dict]]:
    """
    Load all markdown posts from POSTS_DIR.
    Returns (featured, rest) where featured is the most recent post.
    Optionally exclude posts by slug (e.g. the about page).
    """
    exclude_slugs = exclude_slugs or []
    posts = []

    for filename in os.listdir(POSTS_DIR):
        if not filename.endswith(".md"):
            continue
        path = os.path.join(POSTS_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            post = frontmatter.load(f)

        slug = post.get("slug", filename.replace(".md", ""))
        if slug in exclude_slugs:
            continue

        date_str = str(post.get("date", "1970-01-01"))
        try:
            date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            date_obj = datetime.min

        posts.append({
            "title": post.get("title", "Untitled"),
            "date": date_str,
            "date_obj": date_obj,
            "slug": slug,
            "summary": post.get("summary", post.content[:160].strip() + "…"),
            "image": post.get("image"),
            "content": markdown2.markdown(
                post.content,
                extras=["fenced-code-blocks", "code-friendly", "tables", "strike"],
            ),
        })

    posts.sort(key=lambda p: p["date_obj"], reverse=True)
    featured = posts[0] if posts else None
    rest = posts[1:] if len(posts) > 1 else []
    return featured, rest


def load_post_by_slug(slug: str) -> dict | None:
    for filename in os.listdir(POSTS_DIR):
        if not filename.endswith(".md"):
            continue
        path = os.path.join(POSTS_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            post = frontmatter.load(f)
        if post.get("slug") == slug:
            return {
                "title": post.get("title", "Untitled"),
                "date": str(post.get("date", "")),
                "summary": post.get("summary", ""),
                "image": post.get("image"),
                "content": markdown2.markdown(
                    post.content,
                    extras=["fenced-code-blocks", "code-friendly", "tables", "strike"],
                ),
            }
    return None

# ── Routes ─────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def homepage(request: Request):
    featured, posts = load_posts(exclude_slugs=["about-me"])
    return templates.TemplateResponse("index.html", {
        "request": request,
        "featured": featured,
        "posts": posts,
    })


@app.get("/blog", response_class=HTMLResponse)
async def blog(request: Request):
    featured, posts = load_posts(exclude_slugs=["about-me"])
    return templates.TemplateResponse("blog.html", {
        "request": request,
        "featured": featured,
        "posts": posts,
    })


@app.get("/about", response_class=HTMLResponse)
async def about(request: Request):
    path = os.path.join(POSTS_DIR, "about.md")
    with open(path, "r", encoding="utf-8") as f:
        post = frontmatter.load(f)
    return templates.TemplateResponse("about.html", {
        "request": request,
        "title": post.get("title", "About"),
        "image": post.get("image"),
        "content": markdown2.markdown(
            post.content,
            extras=["fenced-code-blocks", "code-friendly"],
        ),
    })


@app.get("/post/{slug}", response_class=HTMLResponse)
async def post_detail(request: Request, slug: str):
    post = load_post_by_slug(slug)
    if not post:
        return templates.TemplateResponse(
            "404.html", {"request": request}, status_code=404
        )
    return templates.TemplateResponse("post.html", {"request": request, **post})


@app.get("/contact", response_class=HTMLResponse)
async def contact_get(request: Request):
    return templates.TemplateResponse("contact.html", {"request": request})


@app.post("/contact", response_class=HTMLResponse)
async def contact_post(
    request: Request,
    name: str = Form(...),
    email: str = Form(...),
    message: str = Form(...),
):
    if not fastmail:
        return templates.TemplateResponse("contact.html", {
            "request": request,
            "error": True,
            "message": "Contact form is not configured on this server.",
        })
    try:
        recipient = os.getenv("MAIL_TO")
        msg = MessageSchema(
            subject=f"[katlauze.dev] message from {name}",
            recipients=[recipient],
            body=f"Name: {name}\nEmail: {email}\n\n{message}",
            subtype="plain",
            headers={"Reply-To": email},
        )
        await fastmail.send_message(msg)
        logger.info("Contact email sent from %s", email)
        return templates.TemplateResponse("contact.html", {
            "request": request,
            "success": True,
            "name": name,
        })
    except Exception as exc:
        logger.error("Failed to send contact email: %s", exc, exc_info=True)
        return templates.TemplateResponse("contact.html", {
            "request": request,
            "error": True,
            "message": "Failed to send — please try again later.",
        })


# Legacy / convenience redirects
@app.get("/index.html")
async def redirect_index():
    return RedirectResponse(url="/", status_code=301)
