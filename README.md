# Brain-Tasks-App — Production Deployment

## Overview
This project deploys the Brain-Tasks-App (a static Vite-built React app) to a production-ready
AWS environment: Dockerized, stored in Amazon ECR, running on an EKS cluster behind a
LoadBalancer, with a fully automated CI/CD pipeline (CodePipeline + CodeBuild) that builds,
pushes, and redeploys automatically on every push to `main`.

## Key links & identifiers

| Item | Value |
|---|---|
| GitHub repository | https://github.com/sravnthikanukula-debug/Brain-Tasks-App |
| ECR repository | `889526028237.dkr.ecr.us-west-2.amazonaws.com/brain-tasks-app` |
| EKS cluster name | `brain-tasks-cluster` (region: `us-west-2`) |
| Application URL (LoadBalancer DNS) | http://af20dac72d1cb4316996ba4c00c7152a-371823994.us-west-2.elb.amazonaws.com |
| **LoadBalancer ARN** | `arn:aws:elasticloadbalancing:us-west-2:889526028237:loadbalancer/af20dac72d1cb4316996ba4c00c7152a` |
| CodeBuild project | `brain-tasks-app-build-proj01` |
| CodePipeline | `brain-tasks-app-pipeline` |
| **Screenshots document** | https://docs.google.com/document/d/1BuUDhbMZcP9mrQEoBKaTV3AxnCuKhw2B2VlfDVE5PIs/view |

## Architecture / pipeline flow

```
Developer push to GitHub (main branch)
        │
        ▼
CodePipeline — Source stage (GitHub App connection, webhook-triggered)
        │
        ▼
CodePipeline — Build stage → AWS CodeBuild project (brain-tasks-app-build-proj01)
        │
        ├─ Installs AWS CLI v2 + kubectl
        ├─ docker build (Dockerfile serves pre-built dist/ via `serve` on port 3000)
        ├─ Push image to Amazon ECR (tagged with commit SHA + latest)
        ├─ aws eks update-kubeconfig
        └─ kubectl apply -f k8s/deployment.yaml, k8s/service.yaml → rolling update on EKS
        │
        ▼
EKS cluster (brain-tasks-cluster, 2 nodes) — 2 pod replicas
        │
        ▼
Kubernetes Service (type: LoadBalancer) → AWS Elastic Load Balancer → public internet
```

CodePipeline has no native "deploy to EKS" action, so the deploy step runs as `kubectl apply`
inside the CodeBuild buildspec — this is the standard pattern for EKS deploys from CodePipeline.

## Setup steps performed

1. **Dev environment** — Ubuntu EC2 instance used as the CLI/build workstation (Docker, AWS CLI
   v2, kubectl, eksctl, git).
2. **Docker** — `Dockerfile` serves the app's pre-built `dist/` folder (Vite static output) using
   `serve` on port 3000. Built and verified locally with `docker build` / `docker run` / `curl`.
3. **Registry (ECR)** — repository `brain-tasks-app` created; image tagged and pushed (`v1`, then
   commit-SHA tags via the pipeline).
4. **Kubernetes / EKS** — cluster `brain-tasks-cluster` created via `eksctl` (2× t3.medium managed
   nodes), confirmed `ACTIVE` with nodes `Ready`. `k8s/deployment.yaml` (2 replicas, resource
   limits, readiness/liveness probes) and `k8s/service.yaml` (type: LoadBalancer) applied and
   verified working, both manually and via the pipeline.
5. **Version control** — code (Dockerfile, k8s/, buildspec.yml, README.md) pushed to this GitHub
   repo via CLI (`git add` / `commit` / `push`, HTTPS + Personal Access Token auth).
6. **CodeBuild** — project `brain-tasks-app-build-proj01` created (Amazon Linux 2 managed image,
   privileged mode enabled for Docker-in-Docker, GitHub App source connection, `buildspec.yml`
   from repo root defines install/build/push/deploy commands).
7. **EKS access for CodeBuild** — granted via an EKS **Access Entry** (cluster uses
   `API_AND_CONFIG_MAP` authentication mode), mapping the CodeBuild service role to
   `AmazonEKSClusterAdminPolicy` so `kubectl apply` from CodeBuild can reach the cluster.
8. **CodePipeline** — `brain-tasks-app-pipeline` created with Source (GitHub, webhook-triggered on
   push to `main`) → Build (the CodeBuild project above) stages; deploy is folded into the Build
   stage's buildspec.
9. **Monitoring (CloudWatch)** — CodeBuild automatically streams logs to
   `/aws/codebuild/brain-tasks-app-build-proj01`, covering install/build/push/deploy logs for
   every run.

## Notable issues encountered & fixes

- **Pre-built static app, not raw source:** the repo ships a Vite `dist/` folder rather than raw
  `src/`/`package.json`, so the Dockerfile simply serves `dist/` directly (no `npm install`/
  `npm run build` needed).
- **`Unknown runtime named 'docker'`:** the Amazon Linux 2 CodeBuild image doesn't accept `docker`
  under `runtime-versions` in buildspec — removed that block (Docker is already available when
  privileged mode is enabled on the project).
- **`the server has asked for the client to provide credentials`:** `kubectl apply` from
  CodeBuild failed authentication against the EKS API even after mapping the IAM role in the
  legacy `aws-auth` ConfigMap. Root cause: the cluster uses EKS's newer **Access Entry**
  authentication system (`API_AND_CONFIG_MAP` mode), which requires registering the role via
  `aws eks create-access-entry` / `aws eks associate-access-policy` rather than relying on the
  ConfigMap alone.

## How to verify the deployment

```bash
kubectl get nodes
kubectl get pods
kubectl get svc brain-tasks-app-svc
curl -I http://af20dac72d1cb4316996ba4c00c7152a-371823994.us-west-2.elb.amazonaws.com
```
Or simply open the Application URL above in a browser.

## Screenshots

All setup and deployment screenshots (Docker running locally, ECR repository, EKS nodes/pods,
LoadBalancer serving the app, successful CodeBuild run, successful CodePipeline run, and
CloudWatch logs) are available here:

**https://docs.google.com/document/d/1BuUDhbMZcP9mrQEoBKaTV3AxnCuKhw2B2VlfDVE5PIs/view**

## Submission summary

- **GitHub repo:** https://github.com/sravnthikanukula-debug/Brain-Tasks-App
- **LoadBalancer ARN:** `arn:aws:elasticloadbalancing:us-west-2:889526028237:loadbalancer/af20dac72d1cb4316996ba4c00c7152a`
- **Live app:** http://af20dac72d1cb4316996ba4c00c7152a-371823994.us-west-2.elb.amazonaws.com