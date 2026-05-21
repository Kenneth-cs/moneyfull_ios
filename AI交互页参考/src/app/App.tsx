import { Sparkles, Send, Menu } from 'lucide-react';
import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import micIcon from '../imports/4d39907f-98b2-4c97-8785-5d8ab1d3e470.png';

interface Message {
  id: number;
  type: 'user' | 'ai';
  content: string;
  time: string;
}

// 可爱的卡皮巴拉SVG组件
const CapybaraAvatar = ({ className = "w-10 h-10" }: { className?: string }) => (
  <svg className={className} viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
    {/* 头部 */}
    <ellipse cx="50" cy="55" rx="35" ry="30" fill="#C5A572"/>
    {/* 耳朵 */}
    <ellipse cx="30" cy="35" rx="8" ry="10" fill="#B89968"/>
    <ellipse cx="70" cy="35" rx="8" ry="10" fill="#B89968"/>
    {/* 耳朵内部 */}
    <ellipse cx="30" cy="37" rx="4" ry="5" fill="#A88858"/>
    <ellipse cx="70" cy="37" rx="4" ry="5" fill="#A88858"/>
    {/* 鼻子 */}
    <ellipse cx="50" cy="60" rx="12" ry="8" fill="#B89968"/>
    {/* 鼻孔 */}
    <ellipse cx="45" cy="60" rx="2" ry="3" fill="#8B6F47"/>
    <ellipse cx="55" cy="60" rx="2" ry="3" fill="#8B6F47"/>
    {/* 眼睛 */}
    <circle cx="38" cy="50" r="4" fill="#2C1810"/>
    <circle cx="62" cy="50" r="4" fill="#2C1810"/>
    {/* 眼睛高光 */}
    <circle cx="39" cy="49" r="1.5" fill="white"/>
    <circle cx="63" cy="49" r="1.5" fill="white"/>
    {/* 嘴巴 */}
    <path d="M 50 65 Q 45 68 40 66" stroke="#8B6F47" strokeWidth="1.5" fill="none" strokeLinecap="round"/>
    <path d="M 50 65 Q 55 68 60 66" stroke="#8B6F47" strokeWidth="1.5" fill="none" strokeLinecap="round"/>
    {/* 腮红 */}
    <ellipse cx="25" cy="55" rx="6" ry="4" fill="#E8B4A0" opacity="0.6"/>
    <ellipse cx="75" cy="55" rx="6" ry="4" fill="#E8B4A0" opacity="0.6"/>
  </svg>
);

export default function App() {
  const [messages, setMessages] = useState<Message[]>([
    { id: 1, type: 'ai', content: '你好！我是你的AI助手，有什么可以帮你的吗？', time: '10:30' },
    { id: 2, type: 'user', content: '帮我规划一下这个月的预算', time: '10:31' },
    { id: 3, type: 'ai', content: '好的！根据你的账单记录，我建议你可以这样分配本月预算：\n\n• 日常开销：¥5,000\n• 储蓄：¥3,000\n• 娱乐：¥2,000', time: '10:31' },
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isTyping, setIsTyping] = useState(false);

  const handleSend = () => {
    if (inputValue.trim()) {
      const newMessage: Message = {
        id: messages.length + 1,
        type: 'user',
        content: inputValue,
        time: new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
      };
      setMessages([...messages, newMessage]);
      setInputValue('');

      // 模拟AI回复
      setIsTyping(true);
      setTimeout(() => {
        const aiMessage: Message = {
          id: messages.length + 2,
          type: 'ai',
          content: '好的，我已经收到你的消息了！让我为你分析一下...',
          time: new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
        };
        setMessages(prev => [...prev, aiMessage]);
        setIsTyping(false);
      }, 1500);
    }
  };

  return (
    <div className="size-full flex items-center justify-center bg-gradient-to-br from-gray-50 to-blue-50/30">
      {/* iOS APP 尺寸容器 (375x812 - iPhone X/11/12/13 standard) */}
      <motion.div
        className="w-[375px] h-[812px] bg-white rounded-[3rem] shadow-2xl overflow-hidden flex flex-col relative"
        style={{ maxHeight: '100vh', maxWidth: '100vw' }}
        initial={{ scale: 0.9, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ duration: 0.3 }}
      >
        {/* 状态栏 */}
        <div className="h-11 bg-white flex items-center justify-center">
          <div className="w-32 h-6 bg-black rounded-full" />
        </div>

        {/* 顶部栏 */}
        <div className="bg-gradient-to-r from-emerald-300 via-teal-300 to-cyan-300 px-5 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <motion.div
                className="w-12 h-12 rounded-full bg-white flex items-center justify-center p-1"
                animate={{ rotate: [0, 3, -3, 0] }}
                transition={{ duration: 4, repeat: Infinity }}
              >
                <CapybaraAvatar className="w-full h-full" />
              </motion.div>
              <motion.div
                className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-green-400 rounded-full border-2 border-white"
                animate={{ scale: [1, 1.2, 1] }}
                transition={{ duration: 2, repeat: Infinity }}
              />
            </div>
            <div>
              <h2 className="font-medium text-white">AI助手</h2>
              <p className="text-xs text-white/80">在线</p>
            </div>
          </div>
          <button className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-colors flex items-center justify-center">
            <Menu className="w-4 h-4 text-white" />
          </button>
        </div>

        {/* 消息列表 */}
        <div className="flex-1 overflow-y-auto px-4 py-5 space-y-4 bg-gradient-to-b from-white to-gray-50/50">
          <AnimatePresence>
            {messages.map((message) => (
              <motion.div
                key={message.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div className={`flex gap-2 max-w-[80%] ${message.type === 'user' ? 'flex-row-reverse' : 'flex-row'}`}>
                  {/* 头像 */}
                  {message.type === 'ai' && (
                    <div className="w-9 h-9 rounded-full bg-white flex items-center justify-center flex-shrink-0 p-1 shadow-sm">
                      <CapybaraAvatar className="w-full h-full" />
                    </div>
                  )}

                  {/* 消息气泡 */}
                  <div className="flex flex-col gap-1">
                    <motion.div
                      className={`px-4 py-3 rounded-2xl ${
                        message.type === 'user'
                          ? 'bg-gradient-to-br from-emerald-400 to-teal-500 text-white rounded-tr-sm'
                          : 'bg-white border border-gray-100 text-gray-800 rounded-tl-sm shadow-sm'
                      }`}
                      whileHover={{ scale: 1.02 }}
                    >
                      <p className="text-sm leading-relaxed whitespace-pre-line">{message.content}</p>
                    </motion.div>
                    <span className={`text-xs text-gray-400 px-2 ${message.type === 'user' ? 'text-right' : 'text-left'}`}>
                      {message.time}
                    </span>
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>

          {/* 正在输入提示 */}
          {isTyping && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex gap-2"
            >
              <div className="w-9 h-9 rounded-full bg-white flex items-center justify-center p-1 shadow-sm">
                <CapybaraAvatar className="w-full h-full" />
              </div>
              <div className="bg-white border border-gray-100 px-4 py-3 rounded-2xl rounded-tl-sm shadow-sm">
                <div className="flex gap-1">
                  <motion.div
                    className="w-2 h-2 bg-gray-400 rounded-full"
                    animate={{ y: [0, -5, 0] }}
                    transition={{ duration: 0.6, repeat: Infinity, delay: 0 }}
                  />
                  <motion.div
                    className="w-2 h-2 bg-gray-400 rounded-full"
                    animate={{ y: [0, -5, 0] }}
                    transition={{ duration: 0.6, repeat: Infinity, delay: 0.2 }}
                  />
                  <motion.div
                    className="w-2 h-2 bg-gray-400 rounded-full"
                    animate={{ y: [0, -5, 0] }}
                    transition={{ duration: 0.6, repeat: Infinity, delay: 0.4 }}
                  />
                </div>
              </div>
            </motion.div>
          )}
        </div>

        {/* 底部输入栏 */}
        <div className="bg-white border-t border-gray-100 px-4 py-3 pb-6">
          <div className="flex items-center gap-2">
            {/* 麦克风按钮 */}
            <motion.button
              className="relative w-12 h-12 flex-shrink-0"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >
              <img src={micIcon} alt="麦克风" className="w-full h-full" />
              <motion.div
                className="absolute inset-0 rounded-full border-2 border-emerald-300"
                animate={{ scale: [1, 1.3], opacity: [0.5, 0] }}
                transition={{ duration: 1.5, repeat: Infinity }}
              />
            </motion.button>

            {/* 输入框 */}
            <div className="flex-1 relative">
              <input
                type="text"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                placeholder="输入消息..."
                className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-full focus:outline-none focus:ring-2 focus:ring-emerald-300 focus:border-transparent transition-all text-sm"
              />
            </div>

            {/* 发送按钮 */}
            <motion.button
              onClick={handleSend}
              className="w-11 h-11 rounded-full bg-gradient-to-br from-cyan-300 to-blue-400 shadow-md hover:shadow-lg transition-shadow flex items-center justify-center flex-shrink-0"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >
              <Send className="w-5 h-5 text-white" strokeWidth={2.5} />
            </motion.button>
          </div>
        </div>

        {/* Home Indicator */}
        <div className="absolute bottom-1 left-1/2 -translate-x-1/2 w-32 h-1 bg-gray-800 rounded-full" />
      </motion.div>
    </div>
  );
}