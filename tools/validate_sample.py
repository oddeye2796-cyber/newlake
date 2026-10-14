#!/usr/bin/env python3
"""예시 A-Box 를 KS X 9101 SHACL 셰이프로 검증한다.
inference='none' — 참조속성의 rdfs:range 로 타입을 추론하면 '잘못된 대상 참조'가
'대상 타입 추가'로 둔갑해 위반이 숨는다. 클래스 계층(subClassOf)만 온톨로지에서 합친다."""
import os, rdflib, pyshacl
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ontology")
data = rdflib.Graph().parse(os.path.join(D, "sample_abox.ttl"))
ont = rdflib.Graph()
for f in ("ksx9101_core.ttl", "arcon_ext.ttl", "lake_meta.ttl"):
    ont.parse(os.path.join(D, f))
shapes = rdflib.Graph().parse(os.path.join(D, "ksx9101_shapes.ttl"))
conf, rg, _ = pyshacl.validate(data, shacl_graph=shapes, ont_graph=ont, inference="none", advanced=True)
print("conforms:", conf)
q = """PREFIX sh:<http://www.w3.org/ns/shacl#>
SELECT ?f ?p ?m WHERE {?r a sh:ValidationResult; sh:focusNode ?f; sh:resultPath ?p; sh:resultMessage ?m}"""
for f, p, m in rg.query(q):
    print(" -", str(f).rsplit("/", 2)[-2] + "/" + str(f).rsplit("/", 1)[-1], "|", str(p).rsplit("/", 1)[-1], "|", m)
