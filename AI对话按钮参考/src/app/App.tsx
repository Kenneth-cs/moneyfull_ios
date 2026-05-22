import { Mic, Sparkles, Send, ArrowLeft, Menu } from 'lucide-react';
import { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';

interface Message {
  id: number;
  type: 'user' | 'ai';
  content: string;
  time: string;
}

// 纯代码重新设计的绿色AI助手图标组件（精致圆形底座 + 剪影 + 右下角麦克风徽章）
const GreenChatIcon = ({ isPressed, isActive }: { isPressed: boolean; isActive: boolean }) => (
  <div className="relative w-full h-full flex items-center justify-center">
    <motion.svg 
      className="w-full h-full drop-shadow-xl" 
      viewBox="0 0 100 100" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
      animate={{ scale: isPressed ? 0.92 : 1 }}
      transition={{ type: "spring", stiffness: 400, damping: 25 }}
    >
      <defs>
        {/* 底座渐变 */}
        <linearGradient id="baseGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#34D399" /> {/* emerald-400 */}
          <stop offset="100%" stopColor="#059669" /> {/* emerald-600 */}
        </linearGradient>
        
        {/* 徽章渐变 */}
        <linearGradient id="badgeGradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#ffffff" />
          <stop offset="100%" stopColor="#ECFDF5" />
        </linearGradient>

        {/* 阴影效果 */}
        <filter id="baseShadow" x="-15%" y="-15%" width="130%" height="130%">
          <feDropShadow dx="0" dy="6" stdDeviation="5" floodColor="#064E3B" floodOpacity="0.25"/>
        </filter>
        <filter id="badgeShadow" x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="3" stdDeviation="3" floodColor="#047857" floodOpacity="0.3"/>
        </filter>
      </defs>

      {/* 声波涟漪效果（长按时外发光扩散） */}
      {isPressed && (
        <g>
          <motion.circle cx="50" cy="50" r="42" stroke="#34D399" strokeWidth="2" fill="none"
            animate={{ r: [42, 60], opacity: [0.6, 0] }}
            transition={{ duration: 1.2, repeat: Infinity }}
          />
          <motion.circle cx="50" cy="50" r="42" stroke="#6EE7B7" strokeWidth="2" fill="none"
            animate={{ r: [42, 60], opacity: [0.6, 0] }}
            transition={{ duration: 1.2, repeat: Infinity, delay: 0.4 }}
          />
        </g>
      )}

      {/* 精致的圆形底座 */}
      <circle cx="50" cy="50" r="42" fill="url(#baseGradient)" filter="url(#baseShadow)" />
      
      {/* 底座内部高光修饰，增加玻璃/立体质感 */}
      <circle cx="50" cy="50" r="40" fill="none" stroke="white" strokeWidth="1" strokeOpacity="0.25" />

      {/* 小满标志性剪影 (柔和可爱的拟物形态) */}
      <g transform="translate(0, -2)">
        {/* 顶部可爱的叶片 */}
        <path d="M 50 22 C 58 10 72 15 68 28 C 65 35 55 30 50 25 Z" fill="#D1FAE5" opacity="0.95"/>
        <path d="M 50 24 C 42 15 30 18 34 28 C 36 33 45 30 50 25 Z" fill="#A7F3D0" opacity="0.85"/>
        
        {/* 胖乎乎的圆润身体剪影 */}
        <path d="M 50 26 C 28 26 20 42 20 56 C 20 70 32 78 50 78 C 68 78 80 70 80 56 C 80 42 72 26 50 26 Z" fill="white" opacity="0.98" />
        
        {/* 可爱的微表情 */}
        <circle cx="38" cy="52" r="3" fill="#059669" />
        <circle cx="62" cy="52" r="3" fill="#059669" />
        <path d="M 46 60 Q 50 64 54 60" fill="none" stroke="#059669" strokeWidth="2.5" strokeLinecap="round" />
        
        {/* 腮红 */}
        <ellipse cx="32" cy="56" rx="4" ry="2.5" fill="#FCA5A5" opacity="0.5" />
        <ellipse cx="68" cy="56" rx="4" ry="2.5" fill="#FCA5A5" opacity="0.5" />
      </g>

      {/* 右下角叠加的微型麦克风徽章 */}
      <g>
        {/* 徽章背景和阴影 */}
        <circle cx="76" cy="76" r="16" fill="url(#badgeGradient)" filter="url(#badgeShadow)" />
        {/* 徽章内高光/边框 */}
        <circle cx="76" cy="76" r="15" fill="none" stroke="#6EE7B7" strokeWidth="1" opacity="0.6" />
        
        {/* 麦克风 SVG 图标 */}
        <g transform="translate(64, 64)">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#059669" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/>
            <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
            <line x1="12" x2="12" y1="19" y2="22"/>
          </svg>
        </g>

        {/* 录音/活跃时的徽章小动效 */}
        {isPressed && (
          <motion.circle cx="76" cy="76" r="16" fill="none" stroke="#059669" strokeWidth="2"
            animate={{ scale: [1, 1.4], opacity: [0.8, 0] }}
            transition={{ duration: 1, repeat: Infinity }}
          />
        )}
      </g>

    </motion.svg>
  </div>
);

export default function App() {
  const [currentPage, setCurrentPage] = useState<'home' | 'chat'>('home');
  const [messages, setMessages] = useState<Message[]>([
    { id: 1, type: 'ai', content: '你好！我是你的AI助手，有什么可以帮你的吗？', time: '10:30' },
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const longPressTimer = useRef<NodeJS.Timeout | null>(null);

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

  const handlePressStart = () => {
    setIsPressed(true);
    longPressTimer.current = setTimeout(() => {
      setIsRecording(true);
    }, 500);
  };

  const handlePressEnd = () => {
    setIsPressed(false);
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
    }

    if (isRecording) {
      setIsRecording(false);
      // 语音录音结束，可以在这里处理语音数据
    } else {
      // 短按跳转到对话页面
      setCurrentPage('chat');
    }
  };

  return (
    <div className="size-full flex items-center justify-center bg-gradient-to-br from-emerald-50 via-green-50 to-teal-50">
      <AnimatePresence mode="wait">
        {currentPage === 'home' ? (
          <motion.div
            key="home"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="w-full max-w-md h-[600px] bg-white rounded-3xl shadow-2xl overflow-hidden flex flex-col relative"
          >
            {/* 主内容区域 */}
            <div className="flex-1 flex flex-col items-center justify-center p-8">
              <h1 className="text-3xl font-medium text-gray-800 mb-2">钱小满</h1>
              <p className="text-gray-500 mb-12">你的AI理财助手</p>

              {/* 功能卡片示例 */}
              <div className="w-full space-y-3">
                <div className="bg-gradient-to-r from-emerald-200 to-teal-200 rounded-2xl p-4 shadow-sm">
                  <p className="text-sm text-emerald-800">今日支出</p>
                  <p className="text-2xl font-medium text-emerald-900 mt-1">¥ 128.00</p>
                </div>
                <div className="bg-gradient-to-r from-blue-200 to-cyan-200 rounded-2xl p-4 shadow-sm">
                  <p className="text-sm text-blue-800">本月预算剩余</p>
                  <p className="text-2xl font-medium text-blue-900 mt-1">¥ 4,520.00</p>
                </div>
              </div>

              {/* 提示文字 */}
              {isRecording && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="mt-8 text-center"
                >
                  <p className="text-lg text-emerald-600 font-medium">正在录音...</p>
                  <p className="text-sm text-gray-500 mt-1">松开停止录音</p>
                </motion.div>
              )}
            </div>

            {/* 底部导航栏 */}
            <div className="bg-white border-t border-gray-200 px-6 py-3 flex items-center justify-around">
              {/* 首页 */}
              <button className="flex flex-col items-center gap-1 px-4 py-2">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
                  <polyline points="9 22 9 12 15 12 15 22"/>
                </svg>
                <span className="text-xs text-gray-600">首页</span>
              </button>

              {/* 账单 */}
              <button className="flex flex-col items-center gap-1 px-4 py-2">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <rect x="3" y="4" width="18" height="16" rx="2"/>
                  <line x1="7" y1="10" x2="17" y2="10"/>
                  <line x1="7" y1="14" x2="13" y2="14"/>
                </svg>
                <span className="text-xs text-gray-600">账单</span>
              </button>

              {/* AI助手图标 */}
              <motion.button
                className="relative -mt-10"
                onMouseDown={handlePressStart}
                onMouseUp={handlePressEnd}
                onMouseLeave={handlePressEnd}
                onTouchStart={handlePressStart}
                onTouchEnd={handlePressEnd}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <div className="w-20 h-20 relative">
                  <GreenChatIcon isPressed={isPressed || isRecording} isActive={true} />
                </div>
                <span className="text-xs text-emerald-600 font-medium mt-1 block">AI助手</span>
              </motion.button>

              {/* 统计 */}
              <button className="flex flex-col items-center gap-1 px-4 py-2">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M3 3v18h18"/>
                  <path d="M18 17V9"/>
                  <path d="M13 17V5"/>
                  <path d="M8 17v-3"/>
                </svg>
                <span className="text-xs text-gray-600">统计</span>
              </button>

              {/* 我的 */}
              <button className="flex flex-col items-center gap-1 px-4 py-2">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                  <circle cx="12" cy="7" r="4"/>
                </svg>
                <span className="text-xs text-gray-600">我的</span>
              </button>
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="chat"
            initial={{ x: 300, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: -300, opacity: 0 }}
            className="w-full max-w-md h-[600px] bg-white rounded-3xl shadow-2xl overflow-hidden flex flex-col"
          >
            {/* 顶部栏 */}
            <div className="bg-gradient-to-r from-emerald-400 via-green-400 to-teal-400 px-5 py-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setCurrentPage('home')}
                  className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-colors flex items-center justify-center"
                >
                  <ArrowLeft className="w-4 h-4 text-white" />
                </button>
                <div className="flex items-center gap-3">
                  <div className="relative">
                    <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center">
                      <div className="w-8 h-8">
                        <GreenChatIcon isPressed={false} isActive={true} />
                      </div>
                    </div>
                    <motion.div
                      className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-400 rounded-full border-2 border-white"
                      animate={{ scale: [1, 1.2, 1] }}
                      transition={{ duration: 2, repeat: Infinity }}
                    />
                  </div>
                  <div>
                    <h2 className="font-medium text-white">AI助手</h2>
                    <p className="text-xs text-white/80">在线</p>
                  </div>
                </div>
              </div>
              <button className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 transition-colors flex items-center justify-center">
                <Menu className="w-4 h-4 text-white" />
              </button>
            </div>

            {/* 消息列表 */}
            <div className="flex-1 overflow-y-auto px-4 py-5 space-y-4 bg-gradient-to-b from-white to-emerald-50/30">
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
                      {message.type === 'ai' && (
                        <div className="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-green-500 flex items-center justify-center flex-shrink-0">
                          <Sparkles className="w-4 h-4 text-white" strokeWidth={2.5} />
                        </div>
                      )}

                      <div className="flex flex-col gap-1">
                        <motion.div
                          className={`px-4 py-3 rounded-2xl ${
                            message.type === 'user'
                              ? 'bg-gradient-to-br from-emerald-500 to-green-600 text-white rounded-tr-sm'
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

              {isTyping && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="flex gap-2"
                >
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-green-500 flex items-center justify-center">
                    <Sparkles className="w-4 h-4 text-white" strokeWidth={2.5} />
                  </div>
                  <div className="bg-white border border-gray-100 px-4 py-3 rounded-2xl rounded-tl-sm shadow-sm">
                    <div className="flex gap-1">
                      <motion.div className="w-2 h-2 bg-gray-400 rounded-full" animate={{ y: [0, -5, 0] }} transition={{ duration: 0.6, repeat: Infinity, delay: 0 }} />
                      <motion.div className="w-2 h-2 bg-gray-400 rounded-full" animate={{ y: [0, -5, 0] }} transition={{ duration: 0.6, repeat: Infinity, delay: 0.2 }} />
                      <motion.div className="w-2 h-2 bg-gray-400 rounded-full" animate={{ y: [0, -5, 0] }} transition={{ duration: 0.6, repeat: Infinity, delay: 0.4 }} />
                    </div>
                  </div>
                </motion.div>
              )}
            </div>

            {/* 底部输入栏 */}
            <div className="bg-white border-t border-gray-100 px-4 py-4">
              <div className="flex items-center gap-2">
                <motion.button
                  className="relative w-11 h-11 rounded-full bg-gradient-to-br from-emerald-400 to-green-500 shadow-md hover:shadow-lg transition-shadow flex items-center justify-center flex-shrink-0"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <Mic className="w-5 h-5 text-white" strokeWidth={2.5} fill="white" />
                  <motion.div
                    className="absolute inset-0 rounded-full border-2 border-emerald-400"
                    animate={{ scale: [1, 1.3], opacity: [0.5, 0] }}
                    transition={{ duration: 1.5, repeat: Infinity }}
                  />
                </motion.button>

                <div className="flex-1 relative">
                  <input
                    type="text"
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                    placeholder="输入消息..."
                    className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-full focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all text-sm"
                  />
                </div>

                <motion.button
                  onClick={handleSend}
                  className="w-11 h-11 rounded-full bg-gradient-to-br from-cyan-400 to-blue-500 shadow-md hover:shadow-lg transition-shadow flex items-center justify-center flex-shrink-0"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <Send className="w-5 h-5 text-white" strokeWidth={2.5} />
                </motion.button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}