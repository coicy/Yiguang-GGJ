# 庭院后续提示词草案（未提交）

额度阻塞后未调用 ImageGen。这些是新高度规则的后续生产说明，不代表存在输出图。

## 完整近景，一次绘制

Use case: stylized-concept. Asset type: one complete 2D game courtyard foreground painting on pure white negative space. Use the existing nursery foreground_onepass.png solely for painterly material, foliage density, roots and outline style. Create a different abandoned greenhouse isolation courtyard: a broad lower arena enclosed by unequal broken glasshouse wall masses and vegetation, a continuous thick root-soil and old masonry foundation, and a two-step rise to an attached safe preparation gallery on the right. Exact world walk contour: (6480,210) to (7040,210), vertical rise to (7040,170), continue to (7160,170), vertical rise to (7160,130), continue to (7440,130). The 560-unit combat floor is continuous and empty. The entry at x6480 connects from y170, a 40-unit drop into the court. Preserve the natural cavity, no separate repeated tile modules or new platforms. In the preparation gallery foundation below the walk edge embed one rounded bright-green living nutrient infusion chamber near (7240,162), and a visibly different horizontal purple pollution drain grille near (7370,166), both part of the wall, never freestanding pots. Keep foliage clear of standing edges and warning space. White space is only empty air and openings, not pale fringes painted around structures. No distant background, characters, UI, text, floor bottles or red warning-like accents. Final pixel canvas and mapping must be fixed against an editable layout image before submission; do not invent a coordinate-to-pixel registration from this text alone.

## 独立整幅后景

Use case: stylized-concept. Asset type: complete low-contrast opaque background layer for the same orthographic side-view isolation courtyard. Follow the approved foreground room canvas and camera exactly. Show receding greenhouse glass bays, misty vegetation and a quiet distant passage with the room's asymmetrical courtyard character. Desaturated teal-green values and soft edges. No near ground, standing platforms, door that resembles a new gameplay exit, central bright object, foreground vines, characters, UI or text. The combat corridor and two-step destination must remain the visually dominant near layer. No repeated nursery vessel.

## 已锁定的画布与几何参考

以 foreground_layout.svg 为几何目标，canvas1920×1200、artOrigin(6480,-250)、artScale0.5。战斗走面像素y920至x1120；两阶分别到y840和y760。绿色腔中心(1520,824)，紫色口中心(1780,832)。background_layout.svg使用完全相同画布。不要改成对称庭院。最终图片由根任务生成。
