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
 * @name Deleting non-property
 * @description The operand of the 'delete' operator should always be a property accessor.
 * @kind problem
 * @problem.severity warning
 * @id js/deletion-of-non-property
 * @tags reliability
 *       maintainability
 *       language-features
 *       external/cwe/cwe-480
 * @precision very-high
 */

import javascript

from DeleteExpr del
where not del.getOperand().stripParens() instanceof PropAccess
select del, "Only properties should be deleted."