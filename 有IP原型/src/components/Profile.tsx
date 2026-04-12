import { Download, Palette, Settings, HelpCircle, LogOut, Edit2, Bell } from 'lucide-react';
import Header from './Header';

export default function Profile({ navigate }: any) {
  return (
    <div className="p-6 pt-12">
      {/* Header */}
      <Header title="个人中心" showLogo={true} />

      {/* User Info */}
      <div className="flex flex-col items-center mb-10">
        <div className="relative mb-4">
          <div className="w-32 h-32 rounded-full p-1 bg-gradient-to-br from-[#A8E6CF] to-white shadow-lg">
            <img 
              src="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" 
              alt="Julian Thorne" 
              className="w-full h-full rounded-full object-cover border-4 border-white"
            />
          </div>
          <button className="absolute bottom-0 right-0 w-10 h-10 bg-[#A8E6CF] border-4 border-[#F9F9F9] rounded-full flex items-center justify-center text-[#2C6957] shadow-sm">
            <Edit2 size={16} />
          </button>
        </div>
        <h2 className="text-3xl font-extrabold text-[#1A1C1C] mb-1">Julian Thorne</h2>
        <p className="text-gray-500 font-medium">高级财务分析师</p>
      </div>

      {/* Stats */}
      <div className="flex gap-4 mb-10">
        <div className="flex-1 bg-[#A8E6CF]/20 rounded-[32px] p-6 flex flex-col items-center justify-center">
          <div className="w-10 h-10 mb-2 text-[#2C6957] flex items-center justify-center">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path><path d="M12 11v6"></path><path d="M9 14h6"></path></svg>
          </div>
          <span className="text-3xl font-black text-[#2C6957] mb-1">12</span>
          <span className="text-sm font-bold text-[#2C6957]/80">活跃项目</span>
        </div>
        <div className="flex-1 bg-[#DCDE8D]/30 rounded-[32px] p-6 flex flex-col items-center justify-center">
          <div className="w-10 h-10 mb-2 text-[#5F621F] flex items-center justify-center">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"></path></svg>
          </div>
          <span className="text-3xl font-black text-[#5F621F] mb-1">48</span>
          <span className="text-sm font-bold text-[#5F621F]/80">总账目</span>
        </div>
      </div>

      {/* Menu */}
      <div className="mb-8">
        <h3 className="text-sm font-black text-gray-400 tracking-widest mb-4 px-2">账户管理</h3>
        <div className="bg-white rounded-[32px] p-2 shadow-sm">
          <MenuItem icon={<Download size={20} />} iconBg="bg-[#FDD1B4]/40" iconColor="text-[#D97736]" title="导出数据" />
          <MenuItem icon={<Palette size={20} />} iconBg="bg-[#A8E6CF]/40" iconColor="text-[#2C6956]" title="主题设置" />
          <MenuItem icon={<Bell size={20} />} iconBg="bg-[#DCDE8D]/60" iconColor="text-[#5F621F]" title="通知偏好" />
          <MenuItem icon={<HelpCircle size={20} />} iconBg="bg-gray-100" iconColor="text-gray-600" title="帮助与反馈" hasBorder={false} />
        </div>
      </div>

      {/* Logout */}
      <button className="w-full bg-[#FFDAD6] text-[#93000A] py-4 rounded-[32px] font-bold text-lg flex items-center justify-center gap-2 shadow-sm">
        <LogOut size={20} /> 退出登录
      </button>
    </div>
  );
}

function MenuItem({ icon, iconBg, iconColor, title, hasBorder = true }: any) {
  return (
    <div className={`flex items-center justify-between p-4 ${hasBorder ? 'border-b border-gray-50' : ''}`}>
      <div className="flex items-center gap-4">
        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${iconBg} ${iconColor}`}>
          {icon}
        </div>
        <span className="text-lg font-bold text-[#1A1C1C]">{title}</span>
      </div>
      <span className="text-gray-300">›</span>
    </div>
  );
}
