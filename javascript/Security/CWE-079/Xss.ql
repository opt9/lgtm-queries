// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * @name Client side cross-site scripting
 * @description Writing user input directly to the DOM allows for
 *              a cross-site scripting vulnerability.
 * @kind problem
 * @problem.severity error
 * @precision medium
 * @tags security
 *       external/cwe/cwe-079
 *       external/cwe/cwe-116
 */

import javascript
import semmle.javascript.security.dataflow.Xss

from XssDataFlowConfiguration xss, DataFlowNode source, DataFlowNode sink
where xss.flowsTo(source, sink)
select sink, "Cross-site scripting vulnerability due to $@.",
       source, "user-provided value"