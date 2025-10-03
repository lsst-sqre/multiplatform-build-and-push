#!/bin/sh

set -eo pipefail

docker_tag() {
    # Determine the tag for Docker images based on GitHub Actions environment
    # variables.

    if [ -n "$GITHUB_HEAD_REF" ]; then
        # For pull requests
        tag=$(echo ${GITHUB_HEAD_REF} | sed -E 's,/,-,g')
    else
        # For push events
        tag=$(echo ${GITHUB_REF} | sed -E 's,refs/(heads|tags)/,,' \
                  | sed -E 's,/,-,g')
    fi
    echo ${tag}
}

calculate_tags() {
    # Distribute the tag over all the push targets, adding -${platform} .
    # We reconsolidate the platforms in the final job of the workflow.
    # If ${additional_tags} is set, distribute those too.
    if [ -z "${tag}" ] || [ -z "${platform}" ] || [ -z "${images}" ]; then
        echo "required variables: tag, platform, images" >&2
        exit 1
    fi
    if [ "${platform}" != "amd64" ] && [ "${platform}" != "arm64" ]; then
        echo "platform must be 'amd64' or 'arm64'" >&2
        exit 1
    fi
    img=$(echo ${images} | cut -d ',' -f 1)
    more=$(echo ${images} | cut -d ',' -f 2- | tr ',' ' ')
    if [ "${img}" = "${more}" ]; then
        more=""
    fi
    tagset="${img}:${tag}-${platform}"
    for m in ${more}; do
        tagset="${tagset},${m}:${tag}-${platform}"
    done
    if [ -n "${additional_tags}" ]; then
        more_tags=$(echo ${additional_tags} | tr ',' ' ')
        for t in ${more_tags}; do
            tagset="${tagset},${img}:${t}-${platform}"
            for m in ${more}; do
                tagset="${tagset},${m}:${t}-${platform}"
            done
        done
    fi
    echo ${tagset}
}
