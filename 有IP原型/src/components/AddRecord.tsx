import React, { useState } from 'react';
import { X, Utensils, ShoppingBag, Car, Home, Gamepad2, HeartPulse, GraduationCap, Settings, ChevronDown, Edit3, Calendar, Delete } from 'lucide-react';

export default function AddRecord({ onClose }: { onClose: () => void }) {
  const [type, setType] = useState<'expense' | 'income'>('expense');
  const [amount, setAmount] = useState('128.50');

  const handleKeyClick = (key: string) => {
    if (key === 'del') {
      setAmount(prev => prev.length > 1 ? prev.slice(0, -1) : '0');
    } else if (key === 'clear') {
      setAmount('0');
    } else {
      setAmount(prev => prev === '0' ? key : prev + key);
    }
  };

  return (
    <div className="absolute inset-0 z-50 bg-[#F9F9F9] flex flex-col animate-in slide-in-from-bottom-full duration-300">
      {/* Header */}
      <div className="flex justify-between items-center p-6 pb-2">
        <button onClick={onClose} className="p-2">
          <X size={24} className="text-gray-800" />
        </button>
        <h2 className="text-xl font-bold text-[#1A1C1C]">记一笔</h2>
        <button onClick={onClose} className="bg-[#546073] text-[#F8F8FF] px-4 py-1.5 rounded-full text-sm font-bold">
          完成
        </button>
      </div>

      {/* Content Scrollable Area */}
      <div className="flex-1 overflow-y-auto px-6 pb-6 hide-scrollbar">
        {/* Toggle */}
        <div className="bg-[#F3F3F3] rounded-full p-1.5 flex mb-6 mx-auto w-48">
          <button 
            onClick={() => setType('expense')}
            className={`flex-1 py-2 rounded-full text-sm font-bold transition-colors ${type === 'expense' ? 'bg-white text-[#1A1C1C] shadow-sm' : 'text-[#404945]'}`}
          >
            支出
          </button>
          <button 
            onClick={() => setType('income')}
            className={`flex-1 py-2 rounded-full text-sm font-bold transition-colors ${type === 'income' ? 'bg-white text-[#1A1C1C] shadow-sm' : 'text-[#404945]'}`}
          >
            收入
          </button>
        </div>

        {/* Amount Input */}
        <div className="bg-[#E5E796] rounded-[48px] p-8 mb-6 relative overflow-hidden flex flex-col items-center">
          <div className="absolute -top-10 -right-10 w-32 h-32 bg-white/20 rounded-full blur-2xl"></div>
          <span className="text-[#484A07]/60 text-sm font-bold tracking-wider mb-2">输入金额</span>
          <div className="flex items-baseline justify-center">
            <span className="text-4xl font-bold text-[#1C1D00] mr-2">¥</span>
            <span className="text-[72px] font-black text-[#1C1D00] tracking-tighter leading-none">{amount}</span>
            <div className="w-1.5 h-12 bg-[#1C1D00] ml-2 animate-pulse rounded-full"></div>
          </div>
        </div>

        {/* Categories */}
        <div className="mb-6">
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-lg font-bold text-[#1A1C1C]">分类</h3>
            <button className="text-xs font-semibold text-gray-500">更多</button>
          </div>
          <div className="grid grid-cols-4 gap-y-6 gap-x-4">
            <CategoryItem icon={<Utensils size={24} />} bg="bg-[#A8E6CF]" label="餐饮" />
            <CategoryItem icon={<ShoppingBag size={24} />} bg="bg-[#FDD1B4]" label="购物" />
            <CategoryItem icon={<Car size={24} />} bg="bg-[#DCDE8D]" label="交通" />
            <CategoryItem icon={<Home size={24} />} bg="bg-[#DBEAFE]" label="居家" />
            <CategoryItem icon={<Gamepad2 size={24} />} bg="bg-[#F3E8FF]" label="娱乐" />
            <CategoryItem icon={<HeartPulse size={24} />} bg="bg-[#FCE7F3]" label="医疗" />
            <CategoryItem icon={<GraduationCap size={24} />} bg="bg-[#FFEDD5]" label="教育" />
            <CategoryItem icon={<Settings size={24} />} bg="bg-[#EEEEEE]" label="设置" />
          </div>
        </div>

        {/* Project Selector */}
        <div className="bg-[#F3F3F3] rounded-full p-4 flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-[#E2E2E2] flex items-center justify-center text-gray-600">
              <Home size={20} />
            </div>
            <div>
              <p className="text-[10px] font-bold text-gray-500 tracking-wider">归属项目</p>
              <p className="text-sm font-bold text-[#1A1C1C]">日常收支 (Daily Living)</p>
            </div>
          </div>
          <ChevronDown size={20} className="text-gray-400" />
        </div>

        {/* Note Input */}
        <div className="bg-[#F3F3F3] rounded-full p-4 flex items-center gap-3 mb-6">
          <div className="w-10 h-10 rounded-full bg-[#E2E2E2] flex items-center justify-center text-gray-600">
            <Edit3 size={20} />
          </div>
          <input 
            type="text" 
            placeholder="添加备注..." 
            className="bg-transparent border-none outline-none flex-1 text-sm font-medium text-[#1A1C1C] placeholder:text-gray-400"
          />
        </div>
      </div>

      {/* Keyboard */}
      <div className="bg-white rounded-t-[48px] p-6 shadow-[0_-20px_40px_rgba(0,0,0,0.05)]">
        <div className="grid grid-cols-4 gap-4">
          <Key label="1" onClick={() => handleKeyClick('1')} />
          <Key label="2" onClick={() => handleKeyClick('2')} />
          <Key label="3" onClick={() => handleKeyClick('3')} />
          <Key icon={<Calendar size={24} />} onClick={() => {}} />
          
          <Key label="4" onClick={() => handleKeyClick('4')} />
          <Key label="5" onClick={() => handleKeyClick('5')} />
          <Key label="6" onClick={() => handleKeyClick('6')} />
          <Key label="+" onClick={() => {}} />
          
          <Key label="7" onClick={() => handleKeyClick('7')} />
          <Key label="8" onClick={() => handleKeyClick('8')} />
          <Key label="9" onClick={() => handleKeyClick('9')} />
          <Key label="-" onClick={() => {}} />
          
          <Key label="." onClick={() => handleKeyClick('.')} />
          <Key label="0" onClick={() => handleKeyClick('0')} />
          <Key icon={<Delete size={24} />} onClick={() => handleKeyClick('del')} />
          <button 
            onClick={onClose}
            className="bg-[#A8E6CF] text-[#2C6957] rounded-[32px] flex items-center justify-center font-extrabold text-lg shadow-sm"
          >
            完成
          </button>
        </div>
      </div>
    </div>
  );
}

function CategoryItem({ icon, bg, label }: { icon: React.ReactNode, bg: string, label: string }) {
  return (
    <div className="flex flex-col items-center gap-2">
      <div className={`w-16 h-16 rounded-full flex items-center justify-center ${bg} text-gray-800 shadow-sm`}>
        {icon}
      </div>
      <span className="text-xs font-bold text-gray-700">{label}</span>
    </div>
  );
}

function Key({ label, icon, onClick }: { label?: string, icon?: React.ReactNode, onClick: () => void }) {
  return (
    <button 
      onClick={onClick}
      className="h-16 bg-[#F3F3F3] rounded-[32px] flex items-center justify-center text-2xl font-bold text-[#1A1C1C] active:bg-gray-200 transition-colors"
    >
      {label || icon}
    </button>
  );
}
