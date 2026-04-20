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
    #
    # If a tag starts with "latest", do not make the -platform version of it;
    # latest* tags are only used for the composite images.
    #
    # We accomplish this by using platform="multi" to include the latest*
    # tags but omit the architecture tags.
    if [ -z "${tag}" ] || [ -z "${platform}" ] || [ -z "${images}" ]; then
        echo "required variables: tag, platform, images" >&2
        exit 1
    fi
    case "${platform}" in
        "amd64" | "arm64")
	    plattag="-${platform}"
            ;;
	"multi")
	    plattag=""
	    ;;
	*)
	    echo "platform must be 'amd64', 'arm64', or 'multi'" >&2
	    ;;
    esac
    img=$(echo ${images} | cut -d ',' -f 1)
    more=$(echo ${images} | cut -d ',' -f 2- | tr ',' ' ')
    if [ "${img}" = "${more}" ]; then
        more=""
    fi
    if [ $(echo ${tag} | cut -c 1-6) == "latest" ]; then
	is_latest="TRUE"
    else
	is_latest=""
    fi
    if [ "${platform}" = "multi" ] || [ -z "${is_latest}" ]; then
	tagset="${img}:${tag}${plattag}"
	for m in ${more}; do
	    tagset="${tagset},${m}:${tag}${plattag}"
	done
    fi
    if [ -n "${additional_tags}" ]; then
        more_tags=$(echo ${additional_tags} | tr ',' ' ')
        for t in ${more_tags}; do
	    if [ $(echo ${t} | cut -c 1-6) == "latest" ]; then
		is_latest="TRUE"
	    else
		is_latest=""
	    fi
	    if [ "${platform}" = "multi" ] || [ -z "${is_latest}" ]; then
		if [ -n "${tagset}" ]; then
		    tagset="${tagset},${img}:${t}${plattag}"
		else
		    tagset="${img}:${t}${plattag}"
		fi
	    fi
            for m in ${more}; do
		if [ "${platform}" = "multi" ] || [ -z "${is_latest}" ]; then
		    # Tagset will have been set by above stanza
	            tagset="${tagset},${m}:${t}${plattag}"
		fi
            done
        done
    fi
    if [ -z "${tagset}" ]; then
	echo "Tag set is empty" >&2
	exit 1
    fi
    echo ${tagset}
}
