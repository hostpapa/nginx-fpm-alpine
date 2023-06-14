#!/usr/bin/env bash
set -Eeuo pipefail

# Check the existence of versions.json file
if [ ! -f versions.json ]; then
	echo "versions.json file does not exist."
fi

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	rm -rf "$version"

	if jq -e '.[env.version] | not' versions.json > /dev/null; then
		echo "deleting $version ..."
		continue
	fi

	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	phpVersion="$(jq -r '.[env.version] | .version' versions.json)"
	eval "phpVersion=( $phpVersion )"

	for dir in "${variants[@]}"; do
		suite="$(dirname "$dir")" # alpine
		variant="$(basename "$dir")" # fpm-nginx
		phpMajorVersion="${version//.}" # 80
		export suite variant phpMajorVersion phpVersion

		alpineVer="${suite#alpine}" # "3.12", etc
		if [ "$suite" != "$alpineVer" ]; then
			from="php:$phpVersion.1-fpm-alpine$alpineVer"
		fi
		export from alpineVer

		case "$variant" in
			fpm) cmd='["php-fpm"]' ;;
			*) cmd='["php", "-a"]' ;;
		esac
		export cmd

		echo "processing $version/$dir ..."
		mkdir -p "$version/$dir"

		{
			generated_warning
			gawk -f "$jqt" 'Dockerfile-linux.template'
		} > "$version/$dir/Dockerfile"

		cp -a \
			templates/* \
			"$version/$dir/"

		cmd="$(jq <<<"$cmd" -r '.[0]')"
		if [ "$cmd" != 'php' ]; then
			sed -i -e 's! php ! '"$cmd"' !g' "$version/$dir/docker-php-entrypoint"
		fi
	done
done

rm -rf .jq-template.awk
