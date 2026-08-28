# Custom Build: kbs-client

This directory contains the `Dockerfile.kbs-client` used to build our custom version of the kbs-client, compiled with **Azure AMD SEV-SNP + vTPM attester** and **Nvidia GPU attester** modules. 

The resulting container is hosted publicly on the GitHub Container Registry (GHCR). This allows our Terraform infrastructure to pull and deploy the image without requiring any authentication tokens.

Isolating the `Dockerfile` here ensures that when Docker builds the image, it doesn't accidentally copy sensitive Terraform state files or cloud credentials from the root directory into the Docker build context.

## How to Build and Push (Manual Update)

If you need to update the tool (e.g., compile a newer version or change the features), follow these steps:

### Prerequisites
1. **Docker** installed on your machine.
2. A **GitHub Personal Access Token (PAT)** with the `write:packages` scope.

### 1. Authenticate with GHCR
Before you can push to the registry, you must log in. Replace `<your-username>` with your GitHub username.

```bash
export CR_PAT="your-personal-access-token"
echo $CR_PAT | docker login ghcr.io -u <your-username> --password-stdin
```

### 2. Build the Image
Navigate into this directory and run the build command. 

*Note: We use the `--no-cache` flag because the `Dockerfile` pulls code directly from a git repository. This forces Docker to fetch the absolute latest commits rather than using a stale local cache.*

```bash
cd kbs-client
docker build -f Dockerfile.kbs-client --no-cache -t ghcr.io/<your-username>/custom-kbs-client-2026-08-16:2026-08-16 .
```

### 3. Push to GHCR
Once built, push the image up to GitHub:

```bash
docker push ghcr.io/<your-username>/custom-kbs-client-2026-08-16:2026-08-16
```

### 4. Verify Public Access
If this is the very first time you are pushing this image, GitHub defaults to making packages **Private**. 
1. Go to your GitHub profile/organization.
2. Click the **Packages** tab.
3. Select `custom-kbs-client-2026-08-16`.
4. Go to **Package Settings** -> **Danger Zone**.
5. Change visibility to **Public** so Terraform can pull it without credentials.

### 5. Update docker-compose.yml file for the workload container
Update the `docker-compose.yml` file in [cloud-config/workload](../cloud-config/workload) directory to reference _your_ GHCR registry:
     
```
image: ghcr.io/<your-username>/custom-kbs-client-2026-08-16:2026-08-16
```
