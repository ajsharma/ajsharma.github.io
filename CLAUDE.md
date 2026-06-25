# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Jekyll blog hosted on GitHub Pages (ajsharma.github.io). Posts are written in Markdown with YAML front matter.

## Commands

**Serve locally (with drafts visible):**
```
bundle exec jekyll serve --watch --drafts
# or
bin/start-jekyll.sh
```

**Lint markdown:**
```
bin/linters/markdown.sh
```

**Lint YAML:**
```
bin/linters/yaml.sh
```

**Create a new draft:**
```
bin/new_draft "Your Post Title"
```

## Content workflow

- `_drafts/` — work-in-progress posts (not published, visible with `--drafts` flag)
- `_posts/` — published posts, filename must be `YYYY-MM-DD-slug.md`
- Publishing a draft: move it from `_drafts/` to `_posts/` with a date prefix

## Post front matter

Posts use `layout: post` and require a `title`. The date is derived from the filename for `_posts/`. Drafts created with `bin/new_draft` get the minimal required front matter automatically.

## Layout architecture

- `_layouts/default.html` — base HTML shell; uses Tailwind CSS (loaded via CDN) with a custom dark theme (`dark-bg`, `text-primary`, etc.) and a constrained `max-w-[42ch]` content column
- `_layouts/home.html` — extends default; renders page content then lists 5 most recent posts
- `_layouts/post.html` — extends default; renders content only (date/title rendered by default.html based on front matter)

Styling is Tailwind utility classes only — there is no build step. The `assets/css/style.css` file supplements Tailwind for any prose/markdown-rendered content.
