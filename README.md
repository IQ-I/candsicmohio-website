# C&S ICM Church — candsicmohio.com

Official website for **C&S International Christian Ministries (ICM) — Cherubim & Seraphim Church, Cincinnati, Ohio**.
Developer: **iDnoBLes Quantum Ideas Inc.**

- Live site (after deploy): https://candsicmohio.com
- Address: 10794 Hamilton Ave, Cincinnati, OH 45231
- Socials: Facebook @icmohio, Instagram @cands.icm.church, TikTok @icmmu, YouTube @icmohio

## What’s in this repo

- `index.html` — full static site (single file, no backend, no build step)
- `assets/logo-icm-v1.jpg`, `assets/logo-icm-founded-2016.jpg` — real church logos supplied by church
- `infra/terraform/` — repeatable IaC for S3 + CloudFront + ACM + Route53 (see below)
- `.github/workflows/deploy.yml` — deploy on push to `main` (OIDC, no long-lived keys)

## Local test

```bash
python3 -m http.server 8000
# open http://localhost:8000
```

## Branches

- `main` — approved site code only
- `infra/aws-hosting` — IaC template + deploy workflow (this folder lives there in GitHub; in this local pack it’s under `infra/` for review)

Do NOT commit secrets. No PATs, no AWS keys in git. Use GitHub OIDC + AWS IAM role.

## Cost — honest note

Not $0-for-life on AWS:
- Domain `candsicmohio.com` (.com) ≈ $12–14/year, every year — not covered by free tier or $100 credit forever.
- Route53 hosted zone $0.50/month ($6/year) if you use Route53 DNS.
- S3 + CloudFront at low church-site traffic is typically a few cents to ~$1/month, often within Always Free limits, but can bill if traffic spikes or logging/WAF is enabled.
- $100 AWS credit helps the first year, it does not make hosting free forever.

Cheapest truly-$0 hosting (except domain renewal) is GitHub Pages or Cloudflare Pages. AWS S3+CloudFront is chosen here for repeatability + control, kept near-$0 by: PriceClass_100, no WAF, no access logging, private S3, compress + caching, no EC2/ALB.

All AWS resources are tagged: Project, Owner, Developer, Environment, CostCenter, ManagedBy, Repo.

## Deploy (only after content approved)

1. Confirm phone/hours + giving link + podcast audio are final.
2. `terraform -chdir=infra/terraform init && terraform plan` — review, then `apply`.
3. Sync: `aws s3 sync . s3://<bucket> --exclude "infra/*" --exclude ".git/*" --delete`
4. Invalidate: `aws cloudfront create-invalidation --distribution-id <id> --paths "/*"`

## Departments & Media/IT

See site sections: Departments (all departments with TBA placeholders for unconfirmed leaders — do not invent names) and Media/IT (C&S Mobile, Scripture Scry iOS/Android, Lets Worship desktop, CAC Mobile, CAC Social, CAC Archive).

## License / ownership

Site content © C&S ICM Church. Code built by iDnoBLes Quantum Ideas Inc. for the church.
