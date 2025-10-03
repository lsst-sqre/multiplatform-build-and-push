# lsst-sqre/multiplatform-build-and-push

A GitHub Actions reusable workflow that creates image tags based on the current Git branch/tag, builds amd64 and arm64 Docker images, pushes those to specified registries, and then generates and pushes a unified manifest so a pull of the base image gets the architecture-appropriate flavor.

## Usage

```yaml
name: CI

"on":
  merge_group: {}
  pull_request: {}
  push:
    tags:
      - "*"

jobs:
  build:
    runs-on: ubuntu-latest

    # (optional) only build on tags or ticket branches
    if: >
      startsWith(github.ref, 'refs/tags/')
      || startsWith(github.head_ref, 'tickets/')

    steps:
      - uses: actions/checkout@v3

      - id: image_names
        env:
          repo: ${{ github.repository }}
        shell: bash
        run: |
          reponame=$(echo ${repo} | cut -d '/' -f 2)
          gar_repo="us-central1.docker.pkg.dev/rubin-shared-services-71ec/sciplat/${reponame}"
          ghcr_repo="ghcr.io/${repo}"
          images="${ghcr_repo},${gar_repo}"
          echo "images=${images}" >> ${GITHUB_OUTPUT}

      - uses: lsst-sqre/multiplatform-build-and-push@v1
        id: build
        with:
          images: ${{ steps.image_names.outputs.images }}
          github_token: ${{ secrets.GITHUB_TOKEN }}

      - run: echo Pushed ${{ steps.image_names.outputs.images }}
```

By default, ghcr.io packages are named after the GitHub repository.
To automatically set that, the above example uses the context variable `${{ github.repository }}` as the image name.

## Action reference

### Inputs

- `image` (string, required) the name of the image to build and push. The image does not include the registry (`ghcr.io/`) or the tag.
  For example, the image input for `ghcr.io/owner/repo:tag` image is `owner/repo`.

- `github_token` (string, required) the GitHub token to use for pushing to ghcr.io. Default is `${{ secrets.GITHUB_TOKEN }}`.

- `dockerfile` (string, optional) the path to the Dockerfile to build. Default is `Dockerfile`.

- `context` (string, optional) the [Docker build context](https://docs.docker.com/build/building/context/). Default is `.`.

- `push` (boolean, optional) a flag to enable pushing to ghcr.io. Default is `true`.
  If `false`, the action skips the push to ghcr.io, but still builds the image with [`docker build`](https://docs.docker.com/engine/reference/commandline/build/).

- `platforms` (list, optional) List of target platform for build.

- `target` (string, optional) the name of a build stage in the Dockerfile to target for the image. This allows multiple images built from a single Dockerfile, e.g., "runtime-A" and "runtime-B".

- `build-args` (list, optional) A list of build-arguments as newline-delimited `arg=value` string pairs. These may be specified in the Dockerfile as `ARG` statements.

- `additional-tags` (list, optional) A newline-delimited list of additional tags to be added to the built image. These can be string literals or can conform to the `docker/metadata-action` [tags grammar](https://github.com/docker/metadata-action?tab=readme-ov-file#tags-input).

### Outputs

- `fully_qualified_image_digest` (string) A complete, unique, and immutable identifier for the built image,
  e.g. `ghcr.io/owner/repo@sha256:4dcaf15076e027f272dc8aba14b1bab77fec44f8aac94c94f1b01ceee8d099d4`.
  This string may be used to reference the built image in `docker pull`, `docker run`, etc.
- `tag` (string) the tag of the image that was pushed to ghcr.io.

## Developer guide

This repository provides a **composite** GitHub Action, a type of action that packages multiple regular actions into a single step.
We do this to make the GitHub Actions of all our software projects more consistent and easier to maintain.
[You can learn more about composite actions in the GitHub documentation.](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)

Create new releases using the GitHub Releases UI and assign a tag with a [semantic version](https://semver.org), including a `v` prefix. Choose the semantic version based on compatibility for users of this workflow. If backwards compatibility is broken, bump the major version.

When a release is made, a new major version tag (i.e. `v1`, `v2`) is also made or moved using [nowactions/update-majorver](https://github.com/marketplace/actions/update-major-version).
We generally expect that most users will track these major version tags.
