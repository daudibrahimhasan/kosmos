from pathlib import Path
import hashlib,json
import onnx,onnxruntime as ort,numpy as np
root=Path(__file__).resolve().parents[1]
options=ort.SessionOptions();options.log_severity_level=4
for name in ['yunet.onnx','sface.onnx']:
    path=root/'assets/models'/name
    model=onnx.load(str(path))
    initializers={v.name for v in model.graph.initializer}
    inputs=[v for v in model.graph.input if v.name not in initializers]
    del model.graph.input[:];model.graph.input.extend(inputs)
    if name=='yunet.onnx':
        model.graph.input[0].type.tensor_type.shape.dim[2].dim_value=320
        model.graph.input[0].type.tensor_type.shape.dim[3].dim_value=320
        del model.graph.value_info[:]
        for value in model.graph.output:
            for dim in value.type.tensor_type.shape.dim:dim.ClearField('dim_value')
        model=onnx.shape_inference.infer_shapes(model)
    onnx.checker.check_model(model);onnx.save(model,str(path))
    session=ort.InferenceSession(str(path),sess_options=options)
    outputs=session.run(None,{session.get_inputs()[0].name:np.zeros(session.get_inputs()[0].shape,dtype=np.float32)})
    print(name,[(v.name,list(o.shape)) for v,o in zip(session.get_outputs(),outputs)])
report_path=root/'docs/model-validation.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
report['artifacts']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in (root/'assets/models').glob('*.onnx')}
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
