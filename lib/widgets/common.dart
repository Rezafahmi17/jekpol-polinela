import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/api.dart';
import '../core/theme.dart';

void showMsg(BuildContext context, String text, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
      backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
      duration: Duration(seconds: error ? 4 : 3),
    ));
}

void showError(BuildContext context, Object e) => showMsg(context, e is ApiException ? e.message : '$e', error: true);

Future<bool> confirm(BuildContext context, String title, String message,
    {String confirmText = 'Ya', String cancelText = 'Batal', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText, style: const TextStyle(color: AppColors.grey))),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 72, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.15 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: light ? Colors.white : AppColors.primaryLight, width: 1.5),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.two_wheeler_rounded,
            size: size * 0.58,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Tombol dengan indikator loading otomatis untuk aksi async.
class LoadingButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final bool outlined;
  final Color? color;
  const LoadingButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.color});

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.outlined ? (widget.color ?? AppColors.primary) : Colors.white;
    final child = _busy
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
          ]);
    final enabled = widget.onPressed != null && !_busy;
    if (widget.outlined) {
      return OutlinedButton(
        style: widget.color == null
            ? null
            : OutlinedButton.styleFrom(foregroundColor: widget.color, side: BorderSide(color: widget.color!)),
        onPressed: enabled ? _tap : null,
        child: child,
      );
    }
    return FilledButton(
      style: widget.color == null ? null : FilledButton.styleFrom(backgroundColor: widget.color),
      onPressed: enabled ? _tap : (_busy ? () {} : null),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusChip(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? bg;
  const Avatar(this.initials, {super.key, this.size = 48, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg ?? AppColors.primaryLight, shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

/// EmptyState yang tetap bisa di-pull-to-refresh.
class EmptyScroll extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyScroll({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: MediaQuery.sizeOf(context).height * 0.14), EmptyState(icon: icon, title: title, subtitle: subtitle)],
      );
}

/// Memuat data async dengan pull-to-refresh, state loading & error yang konsisten.
class AsyncPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data) builder;
  final Duration? autoRefresh;
  const AsyncPage({super.key, required this.load, required this.builder, this.autoRefresh});

  @override
  State<AsyncPage> createState() => AsyncPageState();
}

class AsyncPageState extends State<AsyncPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = _data == null);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return ListView(children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat data',
          subtitle: _error is ApiException ? (_error as ApiException).message : '$_error',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(160, 46)),
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ),
      ]);
    }
    return RefreshIndicator(onRefresh: reload, color: AppColors.primary, child: widget.builder(context, _data!));
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow(this.icon, this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.grey))),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? AppColors.text)),
        ),
      ]),
    );
  }
}

/// Garis rute: titik jemput → tujuan.
class RouteSummary extends StatelessWidget {
  final String pickup;
  final String dest;
  final VoidCallback? onTapPickup;
  final VoidCallback? onTapDest;
  const RouteSummary({super.key, required this.pickup, required this.dest, this.onTapPickup, this.onTapDest});

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String text, Color c, IconData i, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(i, color: c, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey, fontWeight: FontWeight.w600)),
                  Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.grey),
            ]),
          ),
        );
    return Column(children: [
      line('JEMPUT', pickup, AppColors.primary, Icons.trip_origin_rounded, onTapPickup),
      Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 12, color: AppColors.greyLight)),
      ),
      line('TUJUAN', dest, AppColors.danger, Icons.location_on_rounded, onTapDest),
    ]);
  }
}

class Stars extends StatelessWidget {
  final double rating;
  final double size;
  const Stars(this.rating, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5,
            (i) => Icon(
                  rating >= i + 1 ? Icons.star_rounded : (rating > i + 0.4 ? Icons.star_half_rounded : Icons.star_outline_rounded),
                  size: size,
                  color: AppColors.warning,
                )),
      );
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.color = AppColors.primary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AppColors.greyLight, borderRadius: BorderRadius.circular(3)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

String latLngText(LatLng p) => '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

