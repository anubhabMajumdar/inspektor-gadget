// Copyright 2019-2021 The Inspektor Gadget authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package types

import (
	eventtypes "github.com/inspektor-gadget/inspektor-gadget/pkg/types"
)

type SortBy int

const (
	ALL SortBy = iota
	READS
	WRITES
	RBYTES
	WBYTES
)

const (
	AllFilesDefault = false
)

var SortByDefault = []string{"-reads", "-writes", "-rbytes", "-wbytes"}

const (
	AllFilesParam = "pid"
)

// Stats represents the operations performed on a single file
type Stats struct {
	eventtypes.CommonData

	Reads      uint64 `json:"reads,omitempty" column:"reads"`
	Writes     uint64 `json:"writes,omitempty" column:"writes"`
	ReadBytes  uint64 `json:"rbytes,omitempty" column:"rbytes"`
	WriteBytes uint64 `json:"wbytes,omitempty" column:"wbytes"`
	Pid        uint32 `json:"pid,omitempty" column:"pid"`
	Tid        uint32 `json:"tid,omitempty" column:"tid"`
	MountNsID  uint64 `json:"mountnsid,omitempty" column:"mountnsid"`
	Filename   string `json:"filename,omitempty" column:"filename"`
	Comm       string `json:"comm,omitempty" column:"comm"`
	FileType   byte   `json:"fileType,omitempty" column:"fileType"` // R = Regular File, S = Socket, O = Other
}
