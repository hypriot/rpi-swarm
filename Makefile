# repo name
BINARY_NAME = $(shell basename `git rev-parse --show-toplevel`)

DATE := $(shell date -Idate)
#$(shell date +"%Y%m%d%H%M")
COMMIT_HASH := $(shell git rev-parse --short HEAD)
#$(shell git log --pretty=format:'%h' -n 1)


VERSION :=$(shell cat VERSION)

# cuts of the first char (here e.g. v0.4 -> 0.4)
STRIP_VERSION :=$(shell cat VERSION | cut -c 2-)

PACKAGE_RELEASE_VERSION = $(DRONE_BUILD_NUMBER)
PACKAGE_RELEASE_VERSION ?= 1

PACKAGE_VERSION=$(VERSION)-$(PACKAGE_RELEASE_VERSION)

PACKAGE_NAME="$(BINARY_NAME)_$(PACKAGE_VERSION)"

DESCRIPTION :=$(shell cat DESCRIPTION)

# url/s3 path to download from
DOWNLOADPATH := $(shell cat DOWNLOADPATH)
# folder to safe the results
BUILD_DIR := $(BUILD_RESULTS)/$(BINARY_NAME)/$(DATE)_$(COMMIT_HASH)

default: download_from_S3 extract dockerbuild dockersave dockerpush

demo:
	echo "please select your targets"
	cat << EOM
	#download_from_S3:
	#download_from_http:
	#extract:

	#dockerbuild:
	#dockersave:
	#dockerpush:

	#dockerpull:
	#compile:
	#build_debian_package:
	#upload_to_packagecloud:

	#get_sources: download_from_S3 extract
	#create_docker_image: get_sources dockerbuild dockersave dockerpush

	#create_arm_binary: compile copy_binary_to_upload_folder
	#create_arm_binary: dockerbuild compile copy_binary_to_upload_folder
	#create_arm_binary: dockerpull  compile copy_binary_to_upload_folder

	#create_arm_deb: create_arm_binary build_debian_package upload_to_packagecloud


	# Drone WebUI variables
	#$$SLACK_WEBHOOK_URL
	#$$PACKAGECLOUD_API_TOKEN
	#$$PACKAGECLOUD_USER_REPO="Hypriot/Schatzkiste"

	#$$REGISTRY_USER
	#$$REGISTRY_PASSWORD
	#$$REGISTRY_USER_EMAIL
	#$$REGISTRY_URL="registry.hypriot.com"
	#$$REGISTRY_NAMESPACE="buildpipeline"

	#$$AWS_DEFAULT_REGION
	#$$AWS_BUCKET
	#$$AWS_ACCESS_KEY_ID
	#$$AWS_SECRET_ACCESS_KEY
	#$$BUILD_RESULTS="/build"
	#$$S3_PREFIX="arm-binaries"

	#files:
	#DESCRIPTION
	#DOWNLOADPATH
	#VERSION

	#other variables
	#BINARY_NAME
	#BINARY_SIZE
	#PACKAGE_VERSION
	#PACKAGE_RELEASE_VERSION
	#PACKAGE_NAME

	##########################################################################


download_from_S3:
	aws s3 cp s3://$(AWS_BUCKET)/$(DOWNLOADPATH) ./binary.tar.gz

download_from_http:
	curl -L $(DOWNLOADPATH) > ./binary.tar.gz

# extract downloaded tar archives to content/
extract:
	mkdir content/
	tar xzf binary.tar.gz -C content/
	ls -la content/

get_sources: download_from_S3 extract

# build a docker image
dockerbuild:
	docker rmi -f $(REGISTRY_NAMESPACE)/$(BINARY_NAME) || true
	docker build -t $(REGISTRY_NAMESPACE)/$(BINARY_NAME) .

# push the docker image to a docker registry
dockerpush:
	# push VERSION
	docker tag -f $(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(VERSION)
	docker push $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(VERSION)
	# push commit SHA
	docker tag -f $(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(COMMIT_HASH)
	docker push $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(COMMIT_HASH)
	# push timestamp
	docker tag -f $(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(DATE)
	docker push $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(DATE)
	# push latest
	docker tag -f $(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest
	docker push $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest
	# remove tags
	docker rmi $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(VERSION) || true
	docker rmi $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(COMMIT_HASH) || true
	docker rmi $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(DATE) || true
	docker rmi $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest || true

# save the image as tar
dockersave:
	mkdir -p $(BUILD_DIR)
	docker tag $(REGISTRY_NAMESPACE)/$(BINARY_NAME):latest hypriot/$(BINARY_NAME)
	docker save --output="$(BUILD_DIR)/$(BINARY_NAME).tar" hypriot/$(BINARY_NAME)

# pull a docker image from a docker registry
dockerpull:
	docker pull $(REGISTRY_URL)/$(REGISTRY_NAMESPACE)/$(BINARY_NAME):$(VERSION)

# upload the created debian package to packagecloud
upload_to_packagecloud:
	echo "upload debian package to package cloud"
	# see documentation for this api call at https://packagecloud.io/docs/api#resource_packages_method_create
	curl -X POST https://$(PACKAGECLOUD_API_TOKEN):@packagecloud.io/api/v1/repos/$(PACKAGECLOUD_USER_REPO)/packages.json 	     -F "package[distro_version_id]=24" -F "package[package_file]=@$(BUILD_DIR)/package/$(PACKAGE_NAME).deb"

copy_binary_to_upload_folder:
	mkdir -p $(BUILD_DIR)/binary/
	cp $(BINARY_NAME) $(BUILD_DIR)/binary/
	cd $(BUILD_DIR)/binary/ && \
	shasum -a 256 $(BINARY_NAME) > $(BINARY_NAME).sha256 && \
	cat $(BINARY_NAME).sha256
#	BINARY_SIZE = $(shell stat -c %s $(BUILD_DIR)/binary/$(BINARY_NAME))

copy_deb_to upload_folder:
	pwd && ls -la .
	cp -r builds/* $(BUILD_DIR)/package/

create_sha256_checksums:
	echo create checksums
	find_files = $(notdir $(wildcard $(BUILD_DIR)/package/*))
	echo $(foreach dir,$(find_files),$(shell cd $(BUILD_DIR)/package && shasum -a 256 $(dir) >> $(dir).sha256))
	cd $(BUILD_DIR)/package && cat *.sha256

build_debian_package:
	echo "build debian package"
	mkdir -p $(BUILD_DIR)/package/$(PACKAGE_NAME)/DEBIAN $(BUILD_DIR)/package/$(PACKAGE_NAME)/usr/local/bin

	# copy package control template and replace version info
	echo -e "Package: <NAME>\nVersion: <VERSION>\nSection: admin\nPriority: optional\nArchitecture: armhf\nEssential: no\nInstalled-Size: <SIZE>\nMaintainer: blog.hypriot.com\nDescription: <DESCRIPTION>" > $(BUILD_DIR)/package/$(PACKAGE_NAME)/DEBIAN/control
	sed -i'' "s/<VERSION>/$(PACKAGE_VERSION)/g" $(BUILD_DIR)/package/$(PACKAGE_NAME/DEBIAN/control
	sed -i'' "s/<NAME>/$(BINARY_NAME)/g" $(BUILD_DIR)/package/$(PACKAGE_NAME/DEBIAN/control
	sed -i'' "s/<SIZE>/$(BINARY_SIZE)/g" $(BUILD_DIR)/package/$(PACKAGE_NAME/DEBIAN/control
	sed -i'' "s/<DESCRIPTION>/$(DESCRIPTION)/g" $(BUILD_DIR)/package/$(PACKAGE_NAME/DEBIAN/control

	# copy consul binary to destination
	cp $(BUILD_DIR)/binary/$(BINARY_NAME) $(BUILD_DIR)/package/$(PACKAGE_NAME)/usr/local/bin

	# actually create package with dpkg-deb
	cd $(BUILD_DIR)/package && 	dpkg-deb --build $(PACKAGE_NAME)

	# remove temporary folder with source package artifacts as they should not be uploaded to AWS S3
	rm -R $(BUILD_DIR)/package/$(PACKAGE_NAME)

compile:
#    docker build -t hypriot/rpi-openvswitch-builder .
#    docker run --rm -ti --cap-add NET_ADMIN -v $(pwd)/builds:/builds hypriot/rpi-openvswitch-builder /bin/bash -c 'modprobe openvswitch && lsmod | grep openvswitch; DEB_BUILD_OPTIONS="parallel=8 nocheck" fakeroot debian/rules binary && cp /src/*.deb /builds/ && chmod a+rw /builds/*'
#    BINARY_SIZE = $(shell stat -c %s $(shell pwd)/builds/$(BINARY_NAME))
# OR
#   "standard" make
# OR
# other ways to generate binaries in the current directory for copying them with the <copy_binary_to_upload_folder> target
# or copying them on your own
