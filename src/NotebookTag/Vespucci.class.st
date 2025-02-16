"
## Usage 

pythonModelA := FamixPythonImporter import: '/Users/mignard/Documents/work/mooseDemo/student_a' asFileReference.
taggedModelA := TagsJsonReader new model: pythonModelA; yourself .
taggedModelA readFrom: '/Users/mignard/Documents/work/mooseDemo/student_a/profile_labels_export_tp_student_A.json' asFileReference.
modelA := taggedModelA model.

vsp := Vespucci new.
vsp notebookId: 1.
dict := vsp famixElementsByLine: modelA.
vsp postFamixSg: dict.


pythonModelB :=  FamixPythonImporter import: '/Users/mignard/Documents/work/mooseDemo/profile_labels_export_student_b' asFileReference. 
taggedModelB := TagsJsonReader new model: pythonModelB; yourself .
taggedModelB readFrom: '/Users/mignard/Documents/work/mooseDemo/profile_labels_export_student_b/profile_labels_export_student_b.json' asFileReference.
modelB := taggedModelB model.

vsp := Vespucci new.
vsp notebookId: 2.
dict := vsp famixElementsByLine: modelB.
vsp postFamixSg: dict.
"
Class {
	#name : 'Vespucci',
	#superclass : 'Object',
	#instVars : [
		'colombusClient',
		'notebookId'
	],
	#category : 'NotebookTag',
	#package : 'NotebookTag'
}

{ #category : 'as yet unclassified' }
Vespucci >> checkForInconsistancy: aNbElmtId [
	"When we create a new nbElmt we should check if others nbElmt exists with the same SG but a different step"

	| res inconsistencies |
	res := colombusClient
		       findIconsistencyOnElmt: aNbElmtId
		       nbId: notebookId.
	colombusClient client isSuccess
		ifTrue: [
			inconsistencies := res.
			1 halt ]
		ifFalse: [
			| req code |
			req := colombusClient client.
			code := req response statusLine code.

			code = 404 ifFalse: [
				1 halt "Probably a server side error , should not appen" ].
			inconsistencies := [  ] ].

"If we have inconsistencies we need to create them in db"
]

{ #category : 'as yet unclassified' }
Vespucci >> famixElementsByLine: aTaggedFamixPythonModel [

	| source dictionary model |
	model := aTaggedFamixPythonModel. "Besoin de faire une copy"
	source := (model allUsing: FamixTFileAnchor)
		          remove:
		          (model allUsing: FamixTFileAnchor) first.

	dictionary := Dictionary new.

	"Boucler sur tous les sourceAnchor de model et remplire le dictionnaire ligne->elmts"
	source do: [ :sourceAnchor | 
		(sourceAnchor startLine to: sourceAnchor endLine) do: [ :line |
			(dictionary at: line ifAbsentPut: [ OrderedCollection new ]) add:
				sourceAnchor ] ].

	^ dictionary
]

{ #category : 'initialization' }
Vespucci >> initialize [ 

	colombusClient := ColombusClient new initClient: 'http://127.0.0.1:8000/'; yourself.
]

{ #category : 'accessing' }
Vespucci >> notebookId [

	^ notebookId
]

{ #category : 'accessing' }
Vespucci >> notebookId: anObject [

	notebookId := anObject
]

{ #category : 'as yet unclassified' }
Vespucci >> postFamixSg: anEntityDict [
	"We want a line by line dictionnary of model entities : self famixElementsByLine"

	"Probleme de duplication si on repase sur un nb deja traite, on va inserer de nouveau les elmts"

	| value tagId sgId notebookElmt elmtID |
	anEntityDict keysAndValuesDo: [ :key :collec |
		collec do: [ :fElment |
			| elem tag source sgFamix |
			elem := fElment element.
			tag := elem tags first name.
			tagId := self tagIdByName: tag.
			source := elem sourceText.

			"Now here we need to check if this SG exist"
			sgFamix := ColombusModelSg new.
			sgFamix typesgId: 4. "Actual string value type"
			sgFamix value: (Dictionary new
					 at: 'source' put: source;
					 yourself).

			value := colombusClient findSgFamix: sgFamix.
			colombusClient client isSuccess
				ifTrue: [ sgId := value at: 'id' ]
				ifFalse: [
					| req code |
					req := colombusClient client.
					code := req response statusLine code.

					code = 404 ifFalse: [
						1 halt "Probably a server side error , should not appen" ].
					sgId := (colombusClient createSgFamix: sgFamix) at: 'id' ]. "here we need to create a new sg"

			notebookElmt := ColombusModelNbElmt new
				                notebookId: notebookId;
				                "Passer la valeur en global"sousgraphfamix_id:
					                sgId;
				                stepId: tagId;
				                linestart: key;
				                lineend: key;
				                yourself.
			elmtID := (colombusClient createNbElmt: notebookElmt) at: 'idelmt'.
			self checkForInconsistancy: elmtID ] ]
]

{ #category : 'as yet unclassified' }
Vespucci >> tagIdByName: aTagName [

	| tagId |
	tagId := colombusClient getStepByName: aTagName.
	colombusClient client isSuccess ifFalse: [
		| req code |
		req := colombusClient client.
		code := req response statusLine code.

		code = 404 ifFalse: [ Error signal: 'Server problem' ].
		Error signal: 'Cannot find step (should exist)' ].

	^ tagId at: 'id'
]
