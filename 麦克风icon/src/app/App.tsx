import { Mic, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { motion } from 'motion/react';

export default function App() {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <div className="size-full flex items-center justify-center bg-gray-50">
      {/* 展示区域 */}
      <div className="flex flex-col items-center gap-12">
        {/* 标题 */}
        <div className="text-center">
          <h1 className="text-2xl mb-2">AI助手对话入口图标</h1>
          <p className="text-gray-500">基于设计风格的清新柔和设计</p>
        </div>

        {/* 图标展示 */}
        <div className="flex gap-8 items-center flex-wrap justify-center">
          {/* 样式1: 薄荷绿渐变 - 可爱麦克风 */}
          <motion.button
            className="relative w-16 h-16 rounded-full bg-gradient-to-br from-emerald-300 to-teal-400 shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onHoverStart={() => setIsHovered(true)}
            onHoverEnd={() => setIsHovered(false)}
          >
            <Mic className="w-7 h-7 text-white" strokeWidth={2.5} fill="white" />
            <motion.div
              className="absolute -top-1 -right-1 w-5 h-5 bg-gradient-to-br from-yellow-300 to-orange-300 rounded-full flex items-center justify-center"
              animate={{ scale: [1, 1.2, 1] }}
              transition={{ duration: 2, repeat: Infinity }}
            >
              <Sparkles className="w-3 h-3 text-white" strokeWidth={2.5} />
            </motion.div>
            {/* 声波效果 */}
            <motion.div
              className="absolute inset-0 rounded-full border-2 border-white/30"
              animate={{ scale: [1, 1.4], opacity: [0.5, 0] }}
              transition={{ duration: 1.5, repeat: Infinity }}
            />
          </motion.button>

          {/* 样式2: 浅蓝渐变 - 可爱麦克风 */}
          <motion.button
            className="relative w-16 h-16 rounded-full bg-gradient-to-br from-cyan-300 to-blue-400 shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <Mic className="w-7 h-7 text-white" strokeWidth={2.5} fill="white" />
            <motion.div
              className="absolute -top-2 -right-2"
              animate={{ rotate: [0, 15, -15, 0] }}
              transition={{ duration: 2, repeat: Infinity }}
            >
              <Sparkles className="w-4 h-4 text-yellow-200" strokeWidth={2.5} fill="yellow" />
            </motion.div>
          </motion.button>

          {/* 样式3: 柔和粉绿 - 可爱麦克风 */}
          <motion.button
            className="relative w-16 h-16 rounded-full bg-gradient-to-br from-green-200 to-emerald-300 shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center overflow-hidden"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <motion.div
              className="absolute inset-0 bg-gradient-to-br from-white/30 to-transparent"
              animate={{ rotate: 360 }}
              transition={{ duration: 10, repeat: Infinity, ease: "linear" }}
            />
            <Mic className="w-7 h-7 text-emerald-700 relative z-10" strokeWidth={2.5} />
            {/* 多重声波 */}
            <motion.div
              className="absolute inset-0 rounded-full border-2 border-emerald-400/40"
              animate={{ scale: [1, 1.3], opacity: [0.6, 0] }}
              transition={{ duration: 1.2, repeat: Infinity }}
            />
            <motion.div
              className="absolute inset-0 rounded-full border-2 border-emerald-400/40"
              animate={{ scale: [1, 1.3], opacity: [0.6, 0] }}
              transition={{ duration: 1.2, repeat: Infinity, delay: 0.4 }}
            />
          </motion.button>

          {/* 样式4: 米黄温暖色 - 可爱麦克风 */}
          <motion.button
            className="relative w-16 h-16 rounded-full bg-gradient-to-br from-amber-200 to-orange-300 shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <Mic className="w-7 h-7 text-orange-700" strokeWidth={2.5} />
            <motion.div
              className="absolute top-0 right-1"
              animate={{
                y: [-2, 2, -2],
                rotate: [0, 10, -10, 0]
              }}
              transition={{ duration: 2, repeat: Infinity }}
            >
              <Sparkles className="w-3 h-3 text-yellow-400" strokeWidth={3} fill="yellow" />
            </motion.div>
          </motion.button>
        </div>

        {/* 大尺寸展示 - 推荐样式 */}
        <div className="mt-8">
          <p className="text-center text-sm text-gray-500 mb-4">推荐样式 - 大尺寸</p>
          <motion.button
            className="relative w-20 h-20 rounded-full bg-gradient-to-br from-emerald-300 via-teal-300 to-cyan-400 shadow-xl hover:shadow-2xl transition-all flex items-center justify-center group"
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.92 }}
          >
            <motion.div
              className="absolute inset-0 rounded-full bg-gradient-to-br from-white/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"
            />
            <Mic className="w-9 h-9 text-white relative z-10" strokeWidth={2.5} fill="white" />
            <motion.div
              className="absolute -top-1.5 -right-1.5 w-7 h-7 bg-gradient-to-br from-yellow-300 to-orange-400 rounded-full flex items-center justify-center shadow-md"
              animate={{
                scale: [1, 1.15, 1],
                rotate: [0, 10, -10, 0]
              }}
              transition={{ duration: 3, repeat: Infinity }}
            >
              <Sparkles className="w-4 h-4 text-white" strokeWidth={2.5} />
            </motion.div>

            {/* 呼吸光晕效果 */}
            <motion.div
              className="absolute inset-0 rounded-full bg-emerald-300"
              animate={{
                scale: [1, 1.3, 1],
                opacity: [0.3, 0, 0.3]
              }}
              transition={{ duration: 2, repeat: Infinity }}
            />

            {/* 声波效果 */}
            <motion.div
              className="absolute inset-0 rounded-full border-3 border-white/40"
              animate={{ scale: [1, 1.5], opacity: [0.6, 0] }}
              transition={{ duration: 1.5, repeat: Infinity }}
            />
            <motion.div
              className="absolute inset-0 rounded-full border-3 border-white/40"
              animate={{ scale: [1, 1.5], opacity: [0.6, 0] }}
              transition={{ duration: 1.5, repeat: Infinity, delay: 0.5 }}
            />
          </motion.button>
        </div>
      </div>
    </div>
  );
}