install_ppa_prerequisites() {

	# Myy : So... The whole idea is that, a good bunch of external sources
	# are PPA.
	# Adding PPA without add-apt-repository is poorly conveninent since
	# you need to reconstruct the URL by hand, and find the GPG key yourself.
	# add-apt-repository does that automatically, and in a way that allows you
	# to remove it cleanly through the same tool.

	# Myy : TODO Try to find a way to install this package only when
	# we encounter a PPA.
	chroot_sdcard_apt_get_install "software-properties-common"

}

add_apt_sources() {

	local potential_paths=""
	local sub_dirs_to_check=". "
	if [[ ! -z "${SELECTED_CONFIGURATION+x}" ]]; then
		sub_dirs_to_check+="config_${SELECTED_CONFIGURATION}"
	fi
	get_all_potential_paths "${DEBOOTSTRAP_SEARCH_RELATIVE_DIRS}" "${sub_dirs_to_check}" "sources/apt"
	get_all_potential_paths "${CLI_SEARCH_RELATIVE_DIRS}" "${sub_dirs_to_check}" "sources/apt"
	get_all_potential_paths "${DESKTOP_ENVIRONMENTS_SEARCH_RELATIVE_DIRS}" "." "sources/apt"
	get_all_potential_paths "${DESKTOP_APPGROUPS_SEARCH_RELATIVE_DIRS}" "${DESKTOP_APPGROUPS_SELECTED}" "sources/apt"

	display_alert "ADDING ADDITIONAL APT SOURCES"

	for apt_sources_dirpath in ${potential_paths}; do
		if [[ -d "${apt_sources_dirpath}" ]]; then
			for apt_source_filepath in "${apt_sources_dirpath}/"*.source; do
				local new_apt_source="$(cat "${apt_source_filepath}")"
				display_alert "Adding APT Source ${new_apt_source}"
				# -y -> Assumes yes to all queries
				# -n -> Do not update package cache after adding
				chroot_sdcard "add-apt-repository -y -n \"${new_apt_source}\""
				display_alert "Return code : $?"

				# temporally exception for jammy
				[[ $RELEASE == "jammy" ]] && find "${SDCARD}/etc/apt/sources.list.d/." -type f \( -name "*.list" ! -name "armbian.list" \) -print0 | xargs -0 sed -i 's/jammy/hirsute/g'

				local apt_source_gpg_filepath="${apt_source_filepath}.gpg"

				# PPA provide GPG keys automatically, it seems.
				# But other repositories (Docker for example) require the
				# user to import GPG keys manually
				# Myy : FIXME We need some automatic Git warnings when someone
				# add a GPG key, since trusting the wrong keys could lead to
				# serious issues.
				if [[ -f "${apt_source_gpg_filepath}" ]]; then
					display_alert "Adding GPG Key ${apt_source_gpg_filepath}"
					local apt_source_gpg_filename="$(basename ${apt_source_gpg_filepath})"
					cp "${apt_source_gpg_filepath}" "${SDCARD}/tmp/${apt_source_gpg_filename}"
					chroot_sdcard "apt-key add \"/tmp/${apt_source_gpg_filename}\""
					echo "APT Key returned : $?"
				fi
			done
		fi
	done

}

add_desktop_package_sources() {
	add_apt_sources
	chroot_sdcard_apt_get "update"
	run_host_command_logged ls -l "${SDCARD}/etc/apt/sources.list.d"
	run_host_command_logged cat "${SDCARD}/etc/apt/sources.list"
}

# a-kind-of-hook, called by install_distribution_agnostic() if it's a desktop build
desktop_postinstall() {

	# disable display manager for the first run
	chroot_sdcard "systemctl --no-reload disable lightdm.service"
	chroot_sdcard "systemctl --no-reload disable gdm3.service"

	# update packages index
	chroot_sdcard_apt_get "update"

	# install per board packages
	if [[ -n ${PACKAGE_LIST_DESKTOP_BOARD} ]]; then
		chroot_sdcard_apt_get_install "$PACKAGE_LIST_DESKTOP_BOARD"
	fi

	# install per family packages
	if [[ -n ${PACKAGE_LIST_DESKTOP_FAMILY} ]]; then
		chroot_sdcard_apt_get_install "$PACKAGE_LIST_DESKTOP_FAMILY"
	fi

}
