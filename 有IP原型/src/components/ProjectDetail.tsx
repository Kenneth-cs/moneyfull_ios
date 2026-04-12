import Header from './Header';
import { Utensils, Home, Plane } from 'lucide-react';

export default function ProjectDetail({ navigate }: any) {
  return (
    <div className="p-6 pt-12 bg-[#F9F9F9] min-h-screen">
      <Header title="项目详情" onBack={() => navigate('projects')} showBell={false} />
      
      {/* Project Summary Card */}
      <div className="bg-white rounded-[32px] p-6 mb-8 shadow-sm border border-gray-50">
        <div className="flex items-center gap-4 mb-6">
          <div className="w-14 h-14 rounded-full bg-[#A8E6CF]/30 flex items-center justify-center text-[#2C6956]">
            <Plane size={28} />
          </div>
          <div>
            <h2 className="text-2xl font-extrabold text-[#1A1C1C]">新疆之旅</h2>
            <p className="text-sm text-gray-500 mt-1 font-medium">2023.10.01 - 2023.10.15</p>
          </div>
        </div>
        
        <div className="flex justify-between text-sm font-bold mb-2">
          <span className="text-gray-600">预算进度</span>
          <span className="text-[#2C6956]">56%</span>
        </div>
        <div className="h-3 bg-gray-100 rounded-full overflow-hidden mb-4">
          <div className="h-full rounded-full bg-gradient-to-r from-[#A8E6CF] to-[#2C6956]" style={{ width: '56%' }}></div>
        </div>
        <div className="flex justify-between text-xs font-semibold text-gray-500">
          <span>已用: ¥8,500</span>
          <span>总预算: ¥15,000</span>
        </div>
      </div>

      {/* Timeline */}
      <h3 className="text-lg font-extrabold text-[#1A1C1C] mb-6">花费记录 (Timeline)</h3>
      <div className="relative pl-4 border-l-2 border-[#A8E6CF]/50 space-y-8 pb-8">
        
        <div className="relative">
          <div className="absolute -left-[21px] top-1 w-3 h-3 bg-[#2C6956] rounded-full border-2 border-[#F9F9F9]"></div>
          <p className="text-xs font-bold text-gray-400 mb-3">10月15日</p>
          <div className="bg-white rounded-2xl p-4 shadow-sm flex items-center gap-4 border border-gray-50">
            <div className="w-10 h-10 rounded-full bg-[#FDD1B4]/30 flex items-center justify-center text-[#D97736]">
              <Utensils size={18} />
            </div>
            <div className="flex-1">
              <h4 className="text-sm font-bold text-[#1A1C1C]">特色烤全羊</h4>
              <p className="text-xs text-gray-500 mt-0.5">餐饮</p>
            </div>
            <span className="text-sm font-extrabold text-[#BA1A1A]">- ¥ 850.00</span>
          </div>
        </div>

        <div className="relative">
          <div className="absolute -left-[21px] top-1 w-3 h-3 bg-[#A8E6CF] rounded-full border-2 border-[#F9F9F9]"></div>
          <p className="text-xs font-bold text-gray-400 mb-3">10月12日</p>
          <div className="bg-white rounded-2xl p-4 shadow-sm flex items-center gap-4 border border-gray-50">
            <div className="w-10 h-10 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#3B82F6]">
              <Home size={18} />
            </div>
            <div className="flex-1">
              <h4 className="text-sm font-bold text-[#1A1C1C]">喀纳斯民宿</h4>
              <p className="text-xs text-gray-500 mt-0.5">住宿</p>
            </div>
            <span className="text-sm font-extrabold text-[#BA1A1A]">- ¥ 1,200.00</span>
          </div>
        </div>

        <div className="relative">
          <div className="absolute -left-[21px] top-1 w-3 h-3 bg-[#A8E6CF] rounded-full border-2 border-[#F9F9F9]"></div>
          <p className="text-xs font-bold text-gray-400 mb-3">10月01日</p>
          <div className="bg-white rounded-2xl p-4 shadow-sm flex items-center gap-4 border border-gray-50">
            <div className="w-10 h-10 rounded-full bg-[#A8E6CF]/30 flex items-center justify-center text-[#2C6956]">
              <Plane size={18} />
            </div>
            <div className="flex-1">
              <h4 className="text-sm font-bold text-[#1A1C1C]">往返机票</h4>
              <p className="text-xs text-gray-500 mt-0.5">交通</p>
            </div>
            <span className="text-sm font-extrabold text-[#BA1A1A]">- ¥ 4,500.00</span>
          </div>
        </div>

      </div>
    </div>
  );
}
