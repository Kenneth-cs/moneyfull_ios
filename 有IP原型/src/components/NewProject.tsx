import Header from './Header';
import { Image, Type, DollarSign } from 'lucide-react';

export default function NewProject({ navigate }: any) {
  return (
    <div className="p-6 pt-12 bg-[#F9F9F9] min-h-screen">
      <Header title="新建项目" onBack={() => navigate('projects')} showBell={false} />
      
      <div className="space-y-6 mt-4">
        {/* Icon Picker */}
        <div className="flex flex-col items-center justify-center mb-8">
          <div className="w-24 h-24 bg-[#E2E2E2] rounded-full flex items-center justify-center text-gray-400 mb-4 shadow-sm border-4 border-white">
            <Image size={32} />
          </div>
          <button className="text-sm font-bold text-[#2C6956] bg-[#A8E6CF]/30 px-4 py-2 rounded-full">
            选择图标 / Emoji
          </button>
        </div>

        {/* Form Fields */}
        <div className="bg-white rounded-[32px] p-6 shadow-sm border border-gray-50 space-y-6">
          <div>
            <label className="text-xs font-bold text-gray-500 mb-2 block ml-2">项目名称</label>
            <div className="bg-[#F3F3F3] rounded-2xl p-4 flex items-center gap-3">
              <Type size={20} className="text-gray-400" />
              <input 
                type="text" 
                placeholder="例如：新疆之旅、房屋装修..." 
                className="bg-transparent border-none outline-none flex-1 text-sm font-bold text-[#1A1C1C] placeholder:text-gray-400"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-bold text-gray-500 mb-2 block ml-2">总预算 (¥)</label>
            <div className="bg-[#F3F3F3] rounded-2xl p-4 flex items-center gap-3">
              <DollarSign size={20} className="text-gray-400" />
              <input 
                type="number" 
                placeholder="0.00" 
                className="bg-transparent border-none outline-none flex-1 text-sm font-bold text-[#1A1C1C] placeholder:text-gray-400"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-bold text-gray-500 mb-2 block ml-2">项目描述 (选填)</label>
            <textarea 
              placeholder="添加一些关于这个项目的描述..." 
              className="bg-[#F3F3F3] rounded-2xl p-4 w-full h-24 resize-none border-none outline-none text-sm font-medium text-[#1A1C1C] placeholder:text-gray-400"
            ></textarea>
          </div>
        </div>

        {/* Submit Button */}
        <button 
          onClick={() => navigate('projects')}
          className="w-full bg-[#1A1C1C] text-white py-4 rounded-full font-extrabold text-lg shadow-lg mt-8 hover:bg-black transition-colors"
        >
          创建项目
        </button>
      </div>
    </div>
  );
}
