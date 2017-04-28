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
 * @name Cast from abstract to concrete collection
 * @description A cast from an abstract collection to a concrete implementation type makes the
 *              code brittle.
 * @kind problem
 * @problem.severity recommendation
 * @tags reliability
 *       maintainability
 *       modularity
 *       external/cwe/cwe-485
 */
import java
import semmle.code.java.Collections

predicate guardedByInstanceOf(VarAccess e, RefType t) {
  exists(IfStmt s, InstanceOfExpr instanceCheck, Type checkType | 
    s.getCondition() = instanceCheck
    and
    instanceCheck.getTypeName().getType() = checkType
    and 
    // The same variable appears as the subject of the `instanceof`.
    instanceCheck.getExpr() = e.getVariable().getAnAccess()
    and
    // The checked type is either the type itself, or a raw version. For example, it is usually
    // fine to check for `x instanceof ArrayList` and then cast to `ArrayList<Foo>`, because
    // the generic parameter is usually known.
    (checkType = t or checkType = t.getSourceDeclaration().(GenericType).getRawType())
    and
    // The expression appears in one of the branches.
    // (We do not verify here whether the guard is correctly implemented.)
    exists (Stmt branch | branch = s.getThen() or branch = s.getElse() |
      branch = e.getEnclosingStmt().getParent+()
    )
  )
}

from CastExpr e, CollectionType c, CollectionType coll, string abstractName, string concreteName
where 
  coll instanceof Interface and
  c instanceof Class and
  // The result of the cast has type `c`.
  e.getType() = c and
  // The expression inside the cast has type `coll`.
  e.getExpr().getType() = coll and
  // The cast does not occur inside a check that the variable has that type.
  // In this case there is not really a break of abstraction, since it is not
  // *assumed* that the variable has that type. In practice, this usually corresponds
  // to a branch optimized for a specific subtype, and then a generic branch.
  not guardedByInstanceOf(e.getExpr(), c) and
  // Exclude results if "unchecked" warnings are deliberately suppressed.
  not e.getEnclosingCallable().suppressesWarningsAbout("unchecked") and
  // Report the qualified names if the names are the same.
  if coll.getName() = c.getName() 
    then (abstractName = coll.getQualifiedName() and concreteName = c.getQualifiedName())
    else (abstractName = coll.getName() and concreteName = c.getName())
select e, "$@ is cast to the concrete type $@, losing abstraction.",
  coll.getSourceDeclaration(), abstractName,
  c.getSourceDeclaration(), concreteName