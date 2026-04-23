import 'package:flutter/material.dart';
import 'wk_colors.dart';

/// 通用分割线组件
/// 基于 TangSengDaoDao view_line 样式复刻
class WKDivider extends StatelessWidget {
  final double? height;
  final Color? color;
  final double? marginLeft;
  final double? marginRight;

  const WKDivider({
    super.key,
    this.height,
    this.color,
    this.marginLeft,
    this.marginRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: marginLeft ?? 0,
        right: marginRight ?? 0,
      ),
      height: height ?? 1,
      color: color ?? WKColors.colorLine,
    );
  }
}

/// 间距分割线（用于分组间隔）
/// 基于 TangSengDaoDao view_line_15 样式复刻
class WKGapDivider extends StatelessWidget {
  final double height;
  final Color? color;

  const WKGapDivider({
    super.key,
    this.height = 15,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? WKColors.homeBg,
    );
  }
}

/// 通用填充分割线
/// 基于 TangSengDaoDao view_line_padding 样式复刻
class WKPaddingDivider extends StatelessWidget {
  final double height;
  final Color? color;

  const WKPaddingDivider({
    super.key,
    this.height = 10,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? WKColors.homeBg,
    );
  }
}
