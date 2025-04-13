import 'package:flutter/material.dart';
import 'dart:math';

class MissionCompleteEffect extends StatefulWidget {
  final int xp;
  final String statType;
  final Color statColor;

  const MissionCompleteEffect({
    Key? key, 
    required this.xp, 
    required this.statType,
    required this.statColor,
  }) : super(key: key);

  static void show(BuildContext context, int xp, String statType, Color statColor) {
    // Check if the context is still valid before showing dialog
    if (context == null || !WidgetsBinding.instance.isRootWidgetAttached) {
      debugPrint('Cannot show mission complete effect: invalid context');
      return;
    }
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => MissionCompleteEffect(
          xp: xp,
          statType: statType,
          statColor: statColor,
        ),
      );
    } catch (e) {
      debugPrint('Error showing mission complete effect: $e');
    }
  }

  @override
  State<MissionCompleteEffect> createState() => _MissionCompleteEffectState();
}

class _MissionCompleteEffectState extends State<MissionCompleteEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _particleAnimation;
  
  final List<ParticleInfo> _particles = [];
  final int particleCount = 30;

  @override
  void initState() {
    super.initState();
    
    try {
      // Create particles
      for (int i = 0; i < particleCount; i++) {
        _particles.add(ParticleInfo(
          Random().nextDouble() * 2 * pi, // angle
          Random().nextDouble() * 200 + 50, // distance
          Random().nextDouble() * 1.5 + 0.5, // speed
          Random().nextDouble() * 5 + 2, // size
          widget.statColor.withOpacity(Random().nextDouble() * 0.6 + 0.4),
        ));
      }
      
      // Set up animations
      _controller = AnimationController(
        duration: const Duration(milliseconds: 2500),
        vsync: this,
      );
      
      _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        ),
      );
      
      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
        ),
      );
      
      _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
      );
      
      // Start animation safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward().then((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error in MissionCompleteEffect.initState: $e');
      // Close dialog on error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // Particles
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: ParticlePainter(
                    particles: _particles,
                    progress: _particleAnimation.value,
                  ),
                );
              },
            ),
            
            // Center message
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'MISSION COMPLETE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '+${widget.xp} XP',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: widget.statColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.statType,
                                  style: TextStyle(
                                    color: widget.statColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' +${(widget.xp / 100).ceil()}',
                                  style: TextStyle(
                                    color: widget.statColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParticleInfo {
  final double angle;
  final double distance;
  final double speed;
  final double size;
  final Color color;
  
  ParticleInfo(this.angle, this.distance, this.speed, this.size, this.color);
}

class ParticlePainter extends CustomPainter {
  final List<ParticleInfo> particles;
  final double progress;
  
  ParticlePainter({required this.particles, required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - progress)
        ..style = PaintingStyle.fill;
      
      final distance = particle.distance * progress * particle.speed;
      final x = center.dx + cos(particle.angle) * distance;
      final y = center.dy + sin(particle.angle) * distance;
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1.0 - progress * 0.5),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
} 