# 核心后续提示词草案（未提交）

额度阻塞后未调用 ImageGen。旧母稿仅供构图参考，最新核心脚面为 y=130。

## 完整近景，一次绘制

Use case: stylized-concept. Asset type: one complete 2D game greenhouse core chamber foreground on pure white empty air. Use nursery foreground_onepass.png solely as plant-root, weathered masonry, dark outline and painterly material style reference, never copy its low tunnel or stairs. Create a monumental high arch of joined greenhouse machinery, load-bearing rooted side walls and one continuous thick vegetated foundation. Exact world span x7440..8620; the entire standing edge stays level at y130. Boss arena x7440..8160 must remain completely open, width720; over that arena no ceiling collision descends below y=-100. Entry and the exit route toward x8370 belong to the same structural shell. No central solid column, no stairs, pits, platform islands, repeated root-strip tiles, ground bottles, UI, characters or warning-like red light. The roots and masonry have natural outer silhouettes and clear narrow standing edges. All open air and passage holes are pure white for the existing cutout shader; do not draw white edge halos. Keep image and source layout canvas registered. Do not place the background core itself into this foreground layer.

## 独立整幅后景

Use case: stylized-concept. Asset type: complete opaque low-contrast background for the approved side-view greenhouse core chamber. Preserve the same camera and canvas as its foreground. Show a quiet distant suspended botanical cultivation heart around world (7800,-30), dull green-blue glass, connected overhead infusion roots and old greenhouse equipment, atmospheric receding structural ribs. Keep the heart's light soft and local, lower contrast than near ground and combatants. No yellow-white hotspot, orange or red emission, no foreground pedestal or column, no sharp distant steps that look playable. Do not duplicate the nursery mother tank. No characters, UI, text or collectible bottles.

## 已锁定的画布与几何参考

以 foreground_layout.svg 为几何目标，canvas2360×1200、artOrigin(7440,-250)、artScale0.5，全脚面像素y760。精英厅在左侧0..1440px，右侧1440..2360px是低出口廊；主拱不在整图中心。后景培养核像素中心(720,440)，不要居中到1180。background_layout.svg使用相同画布。最终图片由根任务生成。
