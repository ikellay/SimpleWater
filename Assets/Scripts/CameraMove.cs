using System;
using UnityEngine;

public class CameraMove : MonoBehaviour
{
	private Mode _currentMode = Mode.Stand;
	private int _modeSize;

	private float _deltaTime;
	
	private void Awake()
	{
		_modeSize = Enum.GetValues(typeof(Mode)).Length;
		_deltaTime = Time.deltaTime;
	}
	
	private void Update()
	{
		if (Input.GetKeyDown(KeyCode.E))
			SwitchToNextMode();

		ControlCamera();
	}
	
	
	private void SwitchToNextMode()
	{
		_currentMode++;

		if ((int) _currentMode == _modeSize)
			_currentMode = 0;
	}

	private void ControlCamera()
	{
		switch (_currentMode)
		{
			case Mode.Stand:
				transform.position = new Vector3(0, 45, -75);
				transform.LookAt(Vector3.zero);
				break;
			
			case Mode.Rotation:
				transform.LookAt(Vector3.zero);
				transform.RotateAround(Vector3.zero, Vector3.up, 5 * _deltaTime);
				break;
			
			case Mode.Free:
				transform.Rotate(-Input.GetAxisRaw("Mouse Y") * 2, 0, 0, Space.Self);
				transform.Rotate(0, Input.GetAxisRaw("Mouse X") * 2, 0, Space.World);
				transform.Translate(Input.GetAxis("Horizontal") * Time.smoothDeltaTime * 25, 0, Input.GetAxis("Vertical") * Time.smoothDeltaTime * 25, Space.Self);
				break;
		}
	}
	
	private enum Mode
	{
		Stand = 0,
		Rotation = 1,
		Free = 2
	}
}