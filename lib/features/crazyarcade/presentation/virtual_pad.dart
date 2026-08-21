import 'package:flutter/material.dart';

/// 화면 가장자리에 띄우는 가상 조이스틱.
///
/// 조이스틱과 물풍선 버튼을 동시에 눌러야 하므로 GestureDetector 대신
/// [Listener]로 포인터를 직접 다룬다. 제스처 아레나를 거치지 않아
/// 두 컨트롤이 서로의 입력을 빼앗지 않는다.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.size,
    required this.onChanged,
  });

  final double size;

  /// 정규화된 방향 (-1..1). 손을 떼면 (0, 0)이 전달된다.
  final void Function(double x, double y) onChanged;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  /// 조이스틱을 잡고 있는 포인터. 다른 손가락의 입력은 무시한다.
  int? _pointerId;
  Offset _knob = Offset.zero;

  double get _radius => widget.size / 2;

  void _update(Offset localPosition) {
    final center = Offset(_radius, _radius);
    var delta = localPosition - center;

    // 손가락이 원 밖으로 나가도 방향은 유지하고 크기만 가장자리에 붙인다.
    final distance = delta.distance;
    if (distance > _radius) {
      delta = delta / distance * _radius;
    }

    setState(() => _knob = delta);
    widget.onChanged(delta.dx / _radius, delta.dy / _radius);
  }

  void _release() {
    _pointerId = null;
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_pointerId != null) return;
        _pointerId = event.pointer;
        _update(event.localPosition);
      },
      onPointerMove: (event) {
        if (event.pointer != _pointerId) return;
        _update(event.localPosition);
      },
      onPointerUp: (event) {
        if (event.pointer == _pointerId) _release();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointerId) _release();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoystickPainter(
            knob: _knob,
            baseColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.18),
            knobColor: colorScheme.primary.withValues(alpha: 0.75),
            edgeColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.baseColor,
    required this.knobColor,
    required this.edgeColor,
  });

  final Offset knob;
  final Color baseColor;
  final Color knobColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = baseColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center + knob, radius * 0.42, Paint()..color = knobColor);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      old.knob != knob || old.knobColor != knobColor;
}

/// 물풍선 설치 버튼. 누르는 순간 한 번 발동한다.
class BalloonButton extends StatefulWidget {
  const BalloonButton({super.key, required this.size, required this.onPressed});

  final double size;
  final VoidCallback onPressed;

  @override
  State<BalloonButton> createState() => _BalloonButtonState();
}

class _BalloonButtonState extends State<BalloonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _down = true);
        widget.onPressed();
      },
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: Container(
              width: widget.size * 0.82,
              height: widget.size * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4AA8E0).withValues(alpha: 0.85),
                border: Border.all(
                  color: colorScheme.surface.withValues(alpha: 0.9),
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.water_drop_rounded,
                color: Colors.white,
                size: widget.size * 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
