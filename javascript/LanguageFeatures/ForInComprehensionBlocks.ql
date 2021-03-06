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
 * @name Use of for-in comprehension blocks
 * @description 'for'-'in' comprehension blocks are a Mozilla-specific language extension
 *              that is no longer supported.
 * @kind problem
 * @problem.severity error
 * @id js/for-in-comprehension
 * @tags portability
 *       maintainability
 *       language-features
 *       external/cwe/cwe-758
 * @precision very-high
 */

import javascript

from ForInComprehensionBlock ficb
select ficb, "For-in comprehension blocks are a non-standard language feature."
