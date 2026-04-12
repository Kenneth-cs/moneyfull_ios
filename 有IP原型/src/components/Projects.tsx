import { Home as HomeIcon, Palette, Plus } from 'lucide-react';
import Header from './Header';

export default function Projects({ navigate }: any) {
  return (
    <div className="p-6 pt-12">
      {/* Header */}
      <Header title="项目中心" showLogo={true} />

      {/* Tabs */}
      <div className="bg-[#F3F3F3] rounded-full p-1.5 flex mb-8">
        <button className="flex-1 bg-[#A8E6CF] text-[#2C6957] py-2.5 rounded-full text-sm font-bold shadow-sm">
          进行中
        </button>
        <button className="flex-1 text-[#404945] py-2.5 rounded-full text-sm font-bold">
          已归档
        </button>
      </div>

      {/* Project List */}
      <div className="space-y-6">
        <ProjectDetailCard 
          icon={<HomeIcon size={24} className="text-[#2C6956]" />}
          iconBg="bg-[#A8E6CF]/30"
          title="海景房装修"
          date="创建于 2023年10月12日"
          status="进行中"
          desc="温馨自然的北欧风格，注重采光与海景视野的最大化，打造宁静的度假居住空间。"
          progress={75}
          spent="75,000"
          remaining="25,000"
          progressColor="from-[#A8E6CF] to-[#2C6956]"
          onClick={() => navigate('project_detail')}
        />

        <ProjectDetailCard 
          icon={<Palette size={24} className="text-[#795841]" />}
          iconBg="bg-[#FDD1B4]/30"
          title="品牌重塑项目"
          date="创建于 2023年11月05日"
          status="策划中"
          statusBg="bg-[#DCDE8D]"
          statusColor="text-[#60621F]"
          desc="为本地精品咖啡馆设计的全新视觉系统，包括LOGO、包装及线上社交媒体视觉。"
          progress={32}
          spent="3,200"
          remaining="6,800"
          progressColor="from-[#E8BEA2] to-[#785741]"
          btnBg="bg-[#FDD1B4]"
          btnColor="text-[#795841]"
          onClick={() => navigate('project_detail')}
        />

        {/* Add New Project Button */}
        <button 
          onClick={() => navigate('new_project')}
          className="w-full border-4 border-dashed border-[#BFC9C3] bg-[#F3F3F3]/50 rounded-[32px] p-8 flex flex-col items-center justify-center gap-4 hover:bg-[#F3F3F3] transition-colors"
        >
          <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center shadow-sm">
            <Plus size={32} className="text-[#404945]" />
          </div>
          <span className="text-lg font-extrabold text-[#404945]">新建项目</span>
        </button>
      </div>
    </div>
  );
}

function ProjectDetailCard({ 
  icon, iconBg, title, date, status, statusBg = "bg-[#FDD1B4]", statusColor = "text-[#795841]", 
  desc, progress, spent, remaining, progressColor, btnBg = "bg-[#A8E6CF]", btnColor = "text-[#2C6957]", onClick 
}: any) {
  return (
    <div className="bg-white rounded-[32px] border border-gray-50 p-6 shadow-sm relative overflow-hidden">
      <div className={`absolute -top-10 -right-10 w-32 h-32 rounded-full blur-3xl ${iconBg}`}></div>
      
      <div className="relative z-10">
        <div className="flex justify-between items-start mb-4">
          <div className="flex gap-4">
            <div className={`w-12 h-12 rounded-full flex items-center justify-center ${iconBg}`}>
              {icon}
            </div>
            <div>
              <h3 className="text-xl font-extrabold text-[#1A1C1C]">{title}</h3>
              <p className="text-xs text-gray-500 font-medium mt-1">{date}</p>
            </div>
          </div>
          <span className={`${statusBg} ${statusColor} text-[10px] font-bold px-3 py-1 rounded-full`}>
            {status}
          </span>
        </div>

        <p className="text-sm text-gray-600 leading-relaxed mb-6">
          {desc}
        </p>

        <div className="mb-6">
          <div className="flex justify-between text-xs font-bold mb-2">
            <span className="text-gray-600">预算进度</span>
            <span className="text-[#2C6956]">{progress}%</span>
          </div>
          <div className="h-3 bg-gray-100 rounded-full overflow-hidden mb-2">
            <div className={`h-full rounded-full bg-gradient-to-r ${progressColor}`} style={{ width: `${progress}%` }}></div>
          </div>
          <div className="flex justify-between text-[11px] font-semibold text-gray-500">
            <span>已用: ¥{spent}</span>
            <span>剩余预算: ¥{remaining}</span>
          </div>
        </div>

        <button 
          onClick={onClick}
          className={`w-full py-3 rounded-full font-extrabold text-base flex items-center justify-center gap-2 ${btnBg} ${btnColor} hover:opacity-90 transition-opacity`}
        >
          查看详情 <span>→</span>
        </button>
      </div>
    </div>
  );
}
