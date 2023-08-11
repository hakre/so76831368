# This file is part of so76831368, Copyright (C) 2023 hakre
# <https://hakre.wordpress.com>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public Licence as
# published by the Free Software Foundation, either version 3 of the
# Licence, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public Licence for more details.
#
# You should have received a copy of the GNU Affero General Public
# Licence along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

export BUILD_CONTAINER           :=    build
       BUILD_CONTAINER_SHELL     :=    /bin/bash


.PHONY : all
all : build test

#: shell : open interactive shell in build container
.PHONY : shell
shell : | build
	docker exec -it $(BUILD_CONTAINER) $(BUILD_CONTAINER_SHELL)

#: sh : open interactive sh shell in build container
.PHONY : sh
sh : | build
	docker exec -it $(BUILD_CONTAINER) /bin/sh

.PHONY : build test
build : build/build.sh.sentinel
	rm -f build/test.sh.sentinel
	touch $<

test : build build/test.sh.sentinel
	touch $(word 2,$^)

build/%.sh.sentinel : %.sh
	@mkdir -p build
	./$<

.PHONY : clean
clean :
	rm -f $(wildcard build/*.sentinel)
